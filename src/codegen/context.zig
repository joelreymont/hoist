//! Cranelift compilation context and main entry point.
//!
//! The Context struct holds persistent data structures between function compilations
//! to avoid repeated allocations. It contains the function being compiled and all
//! analysis results (CFG, dominator tree, loop analysis, etc.).

const std = @import("std");
const ir = @import("../ir.zig");
const Function = ir.Function;
const ControlFlowGraph = ir.ControlFlowGraph;
const DominatorTree = ir.DominatorTree;
const LoopInfo = ir.LoopInfo;

/// Persistent data structures and compilation pipeline.
pub const Context = struct {
    /// Allocator for all context data.
    allocator: std.mem.Allocator,

    /// The function being compiled.
    func: Function,

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

    pub fn init(allocator: std.mem.Allocator) Context {
        return .{
            .allocator = allocator,
            .func = Function.init(allocator),
            .cfg = ControlFlowGraph.init(allocator),
            .domtree = DominatorTree.init(allocator),
            .loop_analysis = LoopInfo.init(allocator),
            .compiled_code = null,
            .want_disasm = false,
        };
    }

    pub fn initForFunction(allocator: std.mem.Allocator, func: Function) Context {
        return .{
            .allocator = allocator,
            .func = func,
            .cfg = ControlFlowGraph.init(allocator),
            .domtree = DominatorTree.init(allocator),
            .loop_analysis = LoopInfo.init(allocator),
            .compiled_code = null,
            .want_disasm = false,
        };
    }

    pub fn deinit(self: *Context) void {
        self.func.deinit();
        self.cfg.deinit();
        self.domtree.deinit();
        self.loop_analysis.deinit();
        if (self.compiled_code) |*code| {
            code.deinit();
        }
    }

    /// Clear all data structures for reuse.
    pub fn clear(self: *Context) void {
        self.func.clear();
        self.cfg.clear();
        self.domtree.clear();
        self.loop_analysis.clear();
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

    /// Allocator for cleanup.
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CompiledCode {
        return .{
            .code = std.ArrayList(u8){},
            .relocs = std.ArrayList(Relocation){},
            .disasm = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CompiledCode) void {
        self.code.deinit(self.allocator);
        self.relocs.deinit(self.allocator);
        if (self.disasm) |*d| {
            d.deinit(self.allocator);
        }
    }
};

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
