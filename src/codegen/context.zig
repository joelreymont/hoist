//! Cranelift compilation context and main entry point.
//!
//! The Context struct holds persistent data structures between function compilations
//! to avoid repeated allocations. It contains the function being compiled and all
//! analysis results (CFG, dominator tree, loop analysis, etc.).

const std = @import("std");
const ir = @import("../ir.zig");
const Function = ir.Function;
const Signature = ir.Signature;
const ControlFlowGraph = ir.ControlFlowGraph;
const DominatorTree = ir.DominatorTree;
const LoopInfo = ir.LoopInfo;

pub const DebugOptions = struct {
    dump_ir: bool,
    dump_dir: ?[]const u8,

    pub fn init() DebugOptions {
        return .{
            .dump_ir = false,
            .dump_dir = null,
        };
    }

    pub fn deinit(self: *DebugOptions, allocator: std.mem.Allocator) void {
        if (self.dump_dir) |dir| {
            allocator.free(dir);
        }
        self.* = DebugOptions.init();
    }

    pub fn enableIrDumps(self: *DebugOptions, allocator: std.mem.Allocator, dir: []const u8) !void {
        if (self.dump_dir) |existing| {
            allocator.free(existing);
        }
        self.dump_dir = try allocator.dupe(u8, dir);
        self.dump_ir = true;
    }

    pub fn loadFromEnv(self: *DebugOptions, allocator: std.mem.Allocator) !void {
        if (self.dump_ir) return;
        const value = std.process.getEnvVarOwned(allocator, "HOIST_DUMP_IR") catch |err| {
            return switch (err) {
                error.EnvironmentVariableNotFound => {},
                else => err,
            };
        };
        if (value.len == 0 or std.mem.eql(u8, value, "1")) {
            allocator.free(value);
            try self.enableIrDumps(allocator, "hoist_dumps");
            return;
        }
        self.dump_dir = value;
        self.dump_ir = true;
    }
};

/// Persistent data structures and compilation pipeline.
pub const Context = struct {
    /// Allocator for all context data.
    allocator: std.mem.Allocator,

    /// The function being compiled.
    func: *Function,

    /// Control flow graph of the function.
    cfg: ControlFlowGraph,

    /// Dominator tree for the function.
    domtree: DominatorTree,

    /// Loop analysis of the function.
    loop_analysis: LoopInfo,

    /// Compiled machine code result (after lowering and emission).
    compiled_code: ?CompiledCode,

    /// Request disassembly output.
    want_disasm: bool,
    /// Debug output options.
    debug: DebugOptions,

    /// Target configuration (features, arch).
    target: ?*const @import("compile.zig").Target,

    pub fn init(allocator: std.mem.Allocator) Context {
        return .{
            .allocator = allocator,
            .func = undefined, // Must be set before use
            .cfg = ControlFlowGraph.init(allocator),
            .domtree = DominatorTree.init(allocator),
            .loop_analysis = LoopInfo.init(allocator),
            .compiled_code = null,
            .want_disasm = false,
            .debug = DebugOptions.init(),
            .target = null,
        };
    }

    pub fn initForFunction(allocator: std.mem.Allocator, func: *Function) Context {
        return .{
            .allocator = allocator,
            .func = func,
            .cfg = ControlFlowGraph.init(allocator),
            .domtree = DominatorTree.init(allocator),
            .loop_analysis = LoopInfo.init(allocator),
            .compiled_code = null,
            .want_disasm = false,
            .debug = DebugOptions.init(),
            .target = null,
        };
    }

    pub fn deinit(self: *Context) void {
        // Note: We don't own func, so don't deinit it
        self.cfg.deinit(self.allocator);
        self.domtree.deinit();
        self.loop_analysis.deinit(self.allocator);
        if (self.compiled_code) |*code| {
            code.deinit();
        }
        self.debug.deinit(self.allocator);
    }

    /// Clear all data structures for reuse.
    pub fn clear(self: *Context) void {
        // Note: Function doesn't support clear(), would need deinit + re-init
        // self.func.clear();
        self.cfg.clear();
        // Note: DominatorTree doesn't support clear(), would need recompute
        // self.domtree.clear();
        // Note: LoopInfo doesn't support clear(), would need recompute
        // self.loop_analysis.clear();
        if (self.compiled_code) |*code| {
            code.deinit();
        }
        self.compiled_code = null;
        self.want_disasm = false;
    }

    /// Get compiled code result (available after compilation).
    pub fn getCompiledCode(self: *const Context) ?*const CompiledCode {
        return if (self.compiled_code) |*code| code else null;
    }

    /// Take ownership of compiled code (clears context's copy).
    pub fn takeCompiledCode(self: *Context) ?CompiledCode {
        const code = self.compiled_code;
        self.compiled_code = null;
        return code;
    }
};

/// Compiled machine code output.
pub const CompiledCode = struct {
    /// Machine code bytes.
    code: std.ArrayList(u8),

    /// Relocations to apply.
    relocs: std.ArrayList(Relocation),

    /// Disassembly text (if requested).
    disasm: ?std.ArrayList(u8),

    /// eh_frame unwind information section (if available).
    eh_frame: ?std.ArrayList(u8),

    /// Whether eh_frame has been registered with runtime.
    eh_frame_registered: bool,

    /// Allocator for cleanup.
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CompiledCode {
        return .{
            .code = std.ArrayList(u8){},
            .relocs = std.ArrayList(Relocation){},
            .disasm = null,
            .eh_frame = null,
            .eh_frame_registered = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CompiledCode) void {
        // Deregister eh_frame before freeing
        if (self.eh_frame_registered) {
            self.deregisterEhFrame();
        }

        self.code.deinit(self.allocator);
        // Free relocation name strings
        for (self.relocs.items) |reloc| {
            self.allocator.free(reloc.name);
        }
        self.relocs.deinit(self.allocator);
        if (self.disasm) |*d| {
            d.deinit(self.allocator);
        }
        if (self.eh_frame) |*ef| {
            ef.deinit(self.allocator);
        }
    }

    /// Register eh_frame with runtime for exception handling.
    /// Attempts modern libunwind API first, falls back to legacy __register_frame.
    pub fn registerEhFrame(self: *CompiledCode) void {
        if (self.eh_frame) |*ef| {
            if (ef.items.len == 0) return;

            const eh_frame_ptr = ef.items.ptr;

            // Try modern libunwind API first (preferred)
            if (unwAddDynamicEhFrameSection(eh_frame_ptr)) {
                self.eh_frame_registered = true;
                return;
            }

            // Fallback to legacy __register_frame (libgcc/older libunwind)
            if (registerFrame(eh_frame_ptr)) {
                self.eh_frame_registered = true;
                return;
            }

            // No registration available - continue without unwinding support
            // This is not fatal; exception handling just won't work for this JIT code
        }
    }

    /// Deregister eh_frame from runtime.
    fn deregisterEhFrame(self: *CompiledCode) void {
        if (self.eh_frame) |*ef| {
            if (ef.items.len == 0) return;

            const eh_frame_ptr = ef.items.ptr;

            // Try modern libunwind API first
            if (unwRemoveDynamicEhFrameSection(eh_frame_ptr)) {
                self.eh_frame_registered = false;
                return;
            }

            // Fallback to legacy __deregister_frame
            if (deregisterFrame(eh_frame_ptr)) {
                self.eh_frame_registered = false;
                return;
            }
        }
    }
};

// External function declarations for libunwind dynamic registration
// These are weak linkage - if not available, function pointers will be null

/// Modern libunwind API for registering eh_frame sections.
extern "c" fn __unw_add_dynamic_eh_frame_section(eh_frame_ptr: [*]const u8) callconv(.c) void;
extern "c" fn __unw_remove_dynamic_eh_frame_section(eh_frame_ptr: [*]const u8) callconv(.c) void;

/// Legacy libgcc/libunwind API for registering eh_frame.
extern "c" fn __register_frame(eh_frame_ptr: [*]const u8) callconv(.c) void;
extern "c" fn __deregister_frame(eh_frame_ptr: [*]const u8) callconv(.c) void;

/// Try modern libunwind registration.
fn unwAddDynamicEhFrameSection(eh_frame_ptr: [*]const u8) bool {
    // Check if symbol is available (weak linkage)
    const func_ptr: ?*const fn ([*]const u8) callconv(.c) void = @ptrFromInt(@intFromPtr(&__unw_add_dynamic_eh_frame_section));
    if (func_ptr == null) return false;

    __unw_add_dynamic_eh_frame_section(eh_frame_ptr);
    return true;
}

/// Try modern libunwind deregistration.
fn unwRemoveDynamicEhFrameSection(eh_frame_ptr: [*]const u8) bool {
    const func_ptr: ?*const fn ([*]const u8) callconv(.c) void = @ptrFromInt(@intFromPtr(&__unw_remove_dynamic_eh_frame_section));
    if (func_ptr == null) return false;

    __unw_remove_dynamic_eh_frame_section(eh_frame_ptr);
    return true;
}

/// Try legacy __register_frame.
fn registerFrame(eh_frame_ptr: [*]const u8) bool {
    const func_ptr: ?*const fn ([*]const u8) callconv(.c) void = @ptrFromInt(@intFromPtr(&__register_frame));
    if (func_ptr == null) return false;

    __register_frame(eh_frame_ptr);
    return true;
}

/// Try legacy __deregister_frame.
fn deregisterFrame(eh_frame_ptr: [*]const u8) bool {
    const func_ptr: ?*const fn ([*]const u8) callconv(.c) void = @ptrFromInt(@intFromPtr(&__deregister_frame));
    if (func_ptr == null) return false;

    __deregister_frame(eh_frame_ptr);
    return true;
}

/// Relocation entry.
pub const Relocation = struct {
    /// Offset in code buffer.
    offset: u32,
    /// Relocation kind.
    kind: RelocKind,
    /// Target symbol name.
    name: []const u8,
    /// Addend to apply.
    addend: i64,
};

/// Relocation kind.
pub const RelocKind = enum {
    /// Absolute 64-bit address.
    abs8,
    /// PC-relative 32-bit offset.
    pcrel4,
    /// AArch64 ADR/ADRP page offset.
    aarch64_adr_prel_pg_hi21,
    /// AArch64 ADD immediate page offset.
    aarch64_add_abs_lo12_nc,
};

// Tests

const testing = std.testing;

test "Context: basic lifecycle" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();

    try testing.expect(ctx.compiled_code == null);
    try testing.expect(!ctx.want_disasm);
}

test "Context: clear and reuse" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();

    ctx.want_disasm = true;
    ctx.clear();

    try testing.expect(ctx.compiled_code == null);
    try testing.expect(!ctx.want_disasm);
}
