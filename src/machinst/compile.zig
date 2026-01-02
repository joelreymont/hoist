const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const lower_mod = @import("lower.zig");
const vcode_mod = @import("vcode.zig");
const buffer_mod = @import("buffer.zig");
const regalloc_mod = @import("regalloc.zig");

/// Compiled machine code output.
pub const CompiledCode = struct {
    /// Generated machine code bytes.
    code: []const u8,
    /// Relocations needed for final linking.
    relocations: []const Relocation,
    /// Trap records for runtime exception handling.
    traps: []const TrapRecord,
    /// Stack frame size in bytes.
    stack_frame_size: u32,
    /// Allocator (for cleanup).
    allocator: Allocator,

    pub fn deinit(self: *CompiledCode) void {
        self.allocator.free(self.code);
        self.allocator.free(self.relocations);
        self.allocator.free(self.traps);
    }
};

/// Relocation entry for external symbols.
pub const Relocation = struct {
    /// Offset in code where relocation is needed.
    offset: u32,
    /// Type of relocation (PC-relative, absolute, etc).
    kind: RelocationKind,
    /// Target symbol name.
    symbol: []const u8,
    /// Addend to add to symbol address.
    addend: i64,
};

/// Relocation kind.
pub const RelocationKind = enum {
    /// Absolute 64-bit address.
    abs64,
    /// PC-relative 32-bit offset.
    pc_rel32,
    /// GOT entry.
    got_pc_rel32,
};

/// Trap record for runtime exception handling.
pub const TrapRecord = struct {
    /// Offset in code where trap can occur.
    offset: u32,
    /// Trap code (bounds check, null check, etc).
    code: TrapCode,
};

/// Trap code identifying the kind of runtime check.
pub const TrapCode = enum {
    /// Stack overflow.
    stack_overflow,
    /// Heap out of bounds.
    heap_out_of_bounds,
    /// Table out of bounds.
    table_out_of_bounds,
    /// Indirect call to null.
    null_reference,
    /// Integer divide by zero.
    integer_divide_by_zero,
    /// Integer overflow.
    integer_overflow,
    /// Unreachable code executed.
    unreachable_code_reached,
};

/// Compilation context holding configuration and state.
pub const CompileCtx = struct {
    /// Allocator for compilation.
    allocator: Allocator,
    /// Target ISA name (for backend selection).
    isa: []const u8,

    pub fn init(allocator: Allocator, isa: []const u8) CompileCtx {
        return .{
            .allocator = allocator,
            .isa = isa,
        };
    }
};

/// Compile an IR function to machine code.
///
/// Pipeline:
/// 1. Lower IR to VCode with virtual registers
/// 2. Allocate physical registers (regalloc)
/// 3. Emit machine code to buffer
/// 4. Extract final code + metadata
///
/// This is the main entry point for code generation.
pub fn compile(
    comptime MachInst: type,
    ctx: CompileCtx,
    func: *const lower_mod.Function,
    backend: lower_mod.LowerBackend(MachInst),
) !CompiledCode {
    // Phase 1: Lower IR to VCode
    var vcode = try lower_mod.lowerFunction(
        MachInst,
        ctx.allocator,
        func,
        backend,
    );
    defer vcode.deinit();

    // Phase 2: Register allocation
    // For now, use simple linear scan allocator
    // TODO: Integrate regalloc2 for production-quality allocation
    var allocator = regalloc_mod.LinearScanAllocator.init(ctx.allocator);
    defer allocator.deinit();

    // Initialize with available registers (x64 example - should come from ISA)
    const int_regs = [_]@import("reg.zig").PReg{
        @import("reg.zig").PReg.new(.int, 0), // RAX
        @import("reg.zig").PReg.new(.int, 1), // RCX
        @import("reg.zig").PReg.new(.int, 2), // RDX
        @import("reg.zig").PReg.new(.int, 3), // RBX
        @import("reg.zig").PReg.new(.int, 6), // RSI
        @import("reg.zig").PReg.new(.int, 7), // RDI
        @import("reg.zig").PReg.new(.int, 8), // R8
        @import("reg.zig").PReg.new(.int, 9), // R9
        @import("reg.zig").PReg.new(.int, 10), // R10
        @import("reg.zig").PReg.new(.int, 11), // R11
    };
    try allocator.initRegs(&int_regs, &.{}, &.{});

    // Perform allocation (simplified - real version walks VCode)
    var allocation = regalloc_mod.Allocation.init(ctx.allocator);
    defer allocation.deinit();

    // Phase 3: Emit machine code
    var buffer = buffer_mod.MachBuffer.init(ctx.allocator);
    defer buffer.deinit();

    // Emit code from VCode (simplified - needs real emitter)
    // TODO: Implement MachInst emission based on backend
    for (vcode.blocks.items) |block| {
        _ = block;
        // Would emit prologue, instructions, epilogue
    }

    // Phase 4: Finalize and extract code
    try buffer.finalize();

    const code = try ctx.allocator.dupe(u8, buffer.data.items);

    // Convert MachReloc to Relocation
    var relocs = try ctx.allocator.alloc(Relocation, buffer.relocs.items.len);
    for (buffer.relocs.items, 0..) |mreloc, i| {
        relocs[i] = .{
            .offset = mreloc.offset,
            .kind = convertRelocKind(mreloc.kind),
            .symbol = try ctx.allocator.dupe(u8, mreloc.name),
            .addend = mreloc.addend,
        };
    }

    // Convert MachTrap to TrapRecord
    var traps = try ctx.allocator.alloc(TrapRecord, buffer.traps.items.len);
    for (buffer.traps.items, 0..) |mtrap, i| {
        traps[i] = .{
            .offset = mtrap.offset,
            .code = mtrap.code,
        };
    }

    // Compute stack frame size from spill slots
    // Each spill slot is 8 bytes (pointer size), aligned to 16 bytes
    const num_spills = allocation.spills.count();
    const spill_bytes = num_spills * 8;
    const stack_frame_size: u32 = @intCast((spill_bytes + 15) & ~@as(usize, 15)); // Align to 16 bytes

    return CompiledCode{
        .code = code,
        .relocations = relocs,
        .traps = traps,
        .stack_frame_size = stack_frame_size,
        .allocator = ctx.allocator,
    };
}

/// Stub backend for testing.
const TestInst = struct {
    opcode: u32,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("inst_{d}", .{self.opcode});
    }
};

fn testLowerInst(
    ctx: *lower_mod.LowerCtx(TestInst),
    inst: lower_mod.Inst,
) !bool {
    // Emit dummy instruction
    try ctx.emit(TestInst{ .opcode = inst.index });
    return true;
}

fn testLowerBranch(
    _: *lower_mod.LowerCtx(TestInst),
    _: lower_mod.Inst,
) !bool {
    return true;
}

/// Convert MachBuffer relocation kind to public Relocation kind.
fn convertRelocKind(kind: buffer_mod.Reloc) RelocationKind {
    return switch (kind) {
        .abs8, .aarch64_abs64 => .abs64,
        .x86_pc_rel_32, .aarch64_call26, .aarch64_jump26 => .pc_rel32,
        .aarch64_adr_prel_pg_hi21, .aarch64_add_abs_lo12_nc, .aarch64_ldst64_abs_lo12_nc => .got_pc_rel32,
        .abs4 => .abs64, // Treat 4-byte as 8-byte for simplicity
    };
}

test "compile basic" {
    const backend = lower_mod.LowerBackend(TestInst){
        .lowerInstFn = testLowerInst,
        .lowerBranchFn = testLowerBranch,
    };

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    const ctx = CompileCtx.init(testing.allocator, "x86_64");

    var code = try compile(TestInst, ctx, &func, backend);
    defer code.deinit();

    // Should produce some code (even if minimal)
    try testing.expect(code.code.len == 0); // Empty function -> empty code
    try testing.expectEqual(@as(usize, 0), code.relocations.len);
    try testing.expectEqual(@as(usize, 0), code.traps.len);
}

test "TrapCode values" {
    try testing.expect(@intFromEnum(TrapCode.stack_overflow) == 0);
    try testing.expect(@intFromEnum(TrapCode.unreachable_code_reached) == 6);
}

test "RelocationKind values" {
    try testing.expect(@intFromEnum(RelocationKind.abs64) == 0);
    try testing.expect(@intFromEnum(RelocationKind.got_pc_rel32) == 2);
}
