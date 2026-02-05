const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const lower_mod = @import("lower.zig");
const vcode_mod = @import("vcode.zig");
const buffer_mod = @import("buffer.zig");
const reg_mod = @import("reg.zig");
const regalloc2_api_mod = @import("regalloc2/api.zig");
const regalloc2_types_mod = @import("regalloc2/types.zig");
const regalloc2_liveness_mod = @import("regalloc2/liveness.zig");
const regalloc2_allocator_mod = @import("regalloc2/allocator.zig");

fn alignTo16(bytes: u32) u32 {
    return (bytes + 15) & ~@as(u32, 15);
}

fn collectRegalloc2Operands(
    comptime MachInst: type,
    allocator: Allocator,
    vcode: *const vcode_mod.VCode(MachInst),
    adapter: *regalloc2_api_mod.RegAllocAdapter,
) !void {
    if (!@hasDecl(MachInst, "getDefs") or !@hasDecl(MachInst, "getUses")) return;

    for (vcode.insns.items) |inst| {
        var inst_copy = inst;
        const defs = try inst_copy.getDefs(allocator);
        defer allocator.free(defs);
        for (defs) |def_vreg| {
            const vreg = regalloc2_types_mod.VReg.new(def_vreg.index());
            try adapter.addOperand(regalloc2_types_mod.Operand.init(vreg, .any_reg, .def));
        }

        const uses = try inst_copy.getUses(allocator);
        defer allocator.free(uses);
        for (uses) |use_vreg| {
            const vreg = regalloc2_types_mod.VReg.new(use_vreg.index());
            try adapter.addOperand(regalloc2_types_mod.Operand.init(vreg, .any_reg, .use));
        }
    }
}

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
    func: *lower_mod.Function,
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

    // Phase 2: Register allocation via regalloc2 adapter + allocator.
    var regalloc_adapter = regalloc2_api_mod.RegAllocAdapter.init(ctx.allocator);
    defer regalloc_adapter.deinit();
    try collectRegalloc2Operands(MachInst, ctx.allocator, &vcode, &regalloc_adapter);

    var regalloc_liveness = regalloc2_liveness_mod.LivenessInfo.init(ctx.allocator);
    defer regalloc_liveness.deinit();

    var regalloc_allocator = try regalloc2_allocator_mod.Allocator.init(ctx.allocator, &regalloc_adapter);
    defer regalloc_allocator.deinit();
    try regalloc_allocator.run(&regalloc_liveness);

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
            .code = switch (mtrap.code) {
                .stack_overflow => .stack_overflow,
                .heap_out_of_bounds => .heap_out_of_bounds,
                .int_div_by_zero => .integer_divide_by_zero,
                .unreachable_code_reached => .unreachable_code_reached,
            },
        };
    }

    // Compute stack frame size from regalloc2 spill bytes and keep ABI alignment.
    const stack_frame_size = alignTo16(regalloc_allocator.next_spill);

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

const TestInstWithRegs = struct {
    opcode: u32,
    def: ?reg_mod.VReg = null,
    use1: ?reg_mod.VReg = null,
    use2: ?reg_mod.VReg = null,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("inst_{d}", .{self.opcode});
    }

    pub fn getDefs(self: *const @This(), allocator: Allocator) ![]reg_mod.VReg {
        if (self.def) |def_vreg| {
            var defs = try allocator.alloc(reg_mod.VReg, 1);
            defs[0] = def_vreg;
            return defs;
        }
        return allocator.alloc(reg_mod.VReg, 0);
    }

    pub fn getUses(self: *const @This(), allocator: Allocator) ![]reg_mod.VReg {
        var count: usize = 0;
        if (self.use1 != null) count += 1;
        if (self.use2 != null) count += 1;

        var uses = try allocator.alloc(reg_mod.VReg, count);
        var i: usize = 0;
        if (self.use1) |use_vreg| {
            uses[i] = use_vreg;
            i += 1;
        }
        if (self.use2) |use_vreg| {
            uses[i] = use_vreg;
        }
        return uses;
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
        .aarch64_adr_prel_pg_hi21,
        .aarch64_add_abs_lo12_nc,
        .aarch64_ldst64_abs_lo12_nc,
        .aarch64_adr_got_page,
        .aarch64_ld64_got_lo12_nc,
        .aarch64_tlsle_add_tprel_hi12,
        .aarch64_tlsle_add_tprel_lo12_nc,
        .aarch64_tlsie_adr_gottprel_page21,
        .aarch64_tlsie_ld64_gottprel_lo12_nc,
        .aarch64_tlsdesc_adr_page21,
        .aarch64_tlsdesc_ld64_lo12,
        .aarch64_tlsdesc_add_lo12,
        .aarch64_tlsdesc_call => .got_pc_rel32,
        .abs4 => .abs64,
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

test "collectRegalloc2Operands tracks max vreg and spill bytes" {
    var vcode = vcode_mod.VCode(TestInstWithRegs).init(testing.allocator);
    defer vcode.deinit();

    const v0 = reg_mod.VReg.new(0, .int);
    const v40 = reg_mod.VReg.new(40, .int);

    _ = try vcode.startBlock(&.{});
    _ = try vcode.addInst(.{
        .opcode = 1,
        .def = v0,
    });
    _ = try vcode.addInst(.{
        .opcode = 2,
        .def = v40,
        .use1 = v0,
    });
    try vcode.finishBlock(0, &.{});

    var adapter = regalloc2_api_mod.RegAllocAdapter.init(testing.allocator);
    defer adapter.deinit();
    try collectRegalloc2Operands(TestInstWithRegs, testing.allocator, &vcode, &adapter);

    try testing.expectEqual(@as(u32, 41), adapter.num_vregs);

    var liveness = regalloc2_liveness_mod.LivenessInfo.init(testing.allocator);
    defer liveness.deinit();

    var allocator = try regalloc2_allocator_mod.Allocator.init(testing.allocator, &adapter);
    defer allocator.deinit();
    try allocator.run(&liveness);

    try testing.expect(allocator.next_spill > 0);
    try testing.expectEqual(@as(u32, 0), alignTo16(allocator.next_spill) % 16);
}

test "TrapCode values" {
    try testing.expect(@intFromEnum(TrapCode.stack_overflow) == 0);
    try testing.expect(@intFromEnum(TrapCode.unreachable_code_reached) == 6);
}

test "RelocationKind values" {
    try testing.expect(@intFromEnum(RelocationKind.abs64) == 0);
    try testing.expect(@intFromEnum(RelocationKind.got_pc_rel32) == 2);
}
