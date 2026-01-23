const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = @import("inst.zig").Inst;
const abi_mod = @import("../../machinst/abi.zig");
const lower_mod = @import("../../machinst/lower.zig");
const compile_mod = @import("../../machinst/compile.zig");

/// RISC-V 64 ISA descriptor.
/// This integrates all riscv64 backend components into a unified interface.
pub const Riscv64ISA = struct {
    /// ISA name.
    pub const name = "riscv64";

    /// Machine instruction type.
    pub const MachInst = Inst;

    /// ABI specification for this ISA.
    pub fn abi(call_conv: abi_mod.CallConv) abi_mod.ABIMachineSpec(u64) {
        return switch (call_conv) {
            .system_v => @import("abi.zig").lp64d(),
            .aapcs64, .windows_fastcall => unreachable,
        };
    }

    /// Lowering backend for instruction selection.
    pub fn lower() lower_mod.LowerBackend(Inst) {
        return @import("lower.zig").Riscv64Lower.backend();
    }

    /// Register information.
    pub const registers = struct {
        /// Number of general-purpose registers (x0-x31).
        pub const num_gpr: u8 = 32;
        /// Number of floating-point registers (f0-f31).
        pub const num_vec: u8 = 32;
        /// Stack pointer register.
        pub const sp_reg = 2; // x2 (sp)
        /// Frame pointer register.
        pub const fp_reg = 8; // x8 (s0/fp)
        /// Link register.
        pub const lr_reg: ?u8 = 1; // x1 (ra)
    };

    /// Compile a function to machine code using this ISA.
    pub fn compileFunction(
        ctx: compile_mod.CompileCtx,
        func: *const lower_mod.Function,
    ) !compile_mod.CompiledCode {
        return compileWithLinearScan(ctx, func);
    }

    fn compileWithLinearScan(
        ctx: compile_mod.CompileCtx,
        func: *const lower_mod.Function,
    ) !compile_mod.CompiledCode {
        const linear_scan_mod = @import("../../regalloc/linear_scan.zig");
        const buffer_mod = @import("../../machinst/buffer.zig");

        // Phase 1: Lower IR to VCode
        var vcode = try lower_mod.lowerFunction(
            Inst,
            ctx.allocator,
            func,
            lower(),
        );
        defer vcode.deinit();

        // Phase 2: Liveness analysis
        const liveness_mod = @import("../../regalloc/liveness.zig");
        var liveness_info = try liveness_mod.LivenessInfo.compute(Inst, ctx.allocator, &vcode);
        defer liveness_info.deinit();

        // Phase 3: Register allocation using linear scan
        const num_int_regs: u32 = 32; // x0-x31
        const num_float_regs: u32 = 32; // f0-f31
        const num_vector_regs: u32 = 32;

        var linear_scan = try linear_scan_mod.LinearScanAllocator.init(
            ctx.allocator,
            num_int_regs,
            num_float_regs,
            num_vector_regs,
        );
        defer linear_scan.deinit();

        var result = try linear_scan.allocate(&liveness_info);
        defer result.deinit();

        // Phase 4: Insert spill/reload instructions
        try insertSpillReloads(&vcode, &result, &liveness_info, ctx.allocator);

        // Phase 5: Apply allocations to VCode
        for (vcode.insns.items) |*inst| {
            try applyAllocations(inst, &result);
        }

        // Phase 6: Emit machine code
        const emit_mod = @import("emit.zig");
        var buffer = buffer_mod.MachBuffer.init(ctx.allocator);
        defer buffer.deinit();

        // Emit each instruction
        for (vcode.insns.items) |inst| {
            try emit_mod.emit(inst, &buffer);
        }

        // Phase 7: Finalize and extract code
        try buffer.finalize();

        const code = try ctx.allocator.dupe(u8, buffer.data.items);

        // Convert relocations
        var relocs = try ctx.allocator.alloc(compile_mod.Relocation, buffer.relocs.items.len);
        for (buffer.relocs.items, 0..) |mreloc, idx| {
            relocs[idx] = .{
                .offset = mreloc.offset,
                .kind = convertRelocKind(mreloc.kind),
                .symbol = try ctx.allocator.dupe(u8, mreloc.name),
                .addend = mreloc.addend,
            };
        }

        // Convert traps
        var traps = try ctx.allocator.alloc(compile_mod.TrapRecord, buffer.traps.items.len);
        for (buffer.traps.items, 0..) |mtrap, idx| {
            traps[idx] = .{
                .offset = mtrap.offset,
                .code = convertTrapCode(mtrap.code),
            };
        }

        // Stack frame size = spill slot size from allocator
        const stack_frame_size: u32 = linear_scan.next_spill_offset;

        return compile_mod.CompiledCode{
            .code = code,
            .relocations = relocs,
            .traps = traps,
            .stack_frame_size = stack_frame_size,
            .allocator = ctx.allocator,
        };
    }

    fn convertRelocKind(kind: @import("../../machinst/buffer.zig").Reloc) compile_mod.RelocationKind {
        return switch (kind) {
            .abs8, .abs4, .aarch64_abs64 => .abs64,
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
            .aarch64_tlsdesc_call,
            => .got_pc_rel32,
        };
    }

    fn convertTrapCode(code: @import("../../machinst/buffer.zig").TrapCode) compile_mod.TrapCode {
        return switch (code) {
            .stack_overflow => .stack_overflow,
            .heap_out_of_bounds => .heap_out_of_bounds,
            .int_div_by_zero => .integer_divide_by_zero,
            .unreachable_code_reached => .unreachable_code_reached,
        };
    }

    fn insertSpillReloads(
        vcode: anytype,
        result: anytype,
        liveness_info: anytype,
        allocator: std.mem.Allocator,
    ) !void {
        _ = vcode;
        _ = result;
        _ = liveness_info;
        _ = allocator;
        // TODO: Implement spill/reload insertion
    }

    fn applyAllocations(inst: *Inst, result: anytype) !void {
        _ = inst;
        _ = result;
        // TODO: Implement vreg->preg rewriting
    }
};

test "Riscv64ISA basic properties" {
    try testing.expectEqualStrings("riscv64", Riscv64ISA.name);
    try testing.expectEqual(@as(u8, 32), Riscv64ISA.registers.num_gpr);
    try testing.expectEqual(@as(u8, 32), Riscv64ISA.registers.num_vec);
    try testing.expectEqual(@as(u8, 2), Riscv64ISA.registers.sp_reg);
    try testing.expectEqual(@as(u8, 8), Riscv64ISA.registers.fp_reg);
    try testing.expectEqual(@as(u8, 1), Riscv64ISA.registers.lr_reg.?);
}

test "Riscv64ISA ABI selection" {
    const lp64d = Riscv64ISA.abi(.system_v);

    // LP64D has 8 int arg regs (a0-a7)
    try testing.expectEqual(@as(usize, 8), lp64d.int_arg_regs.len);

    // LP64D has 8 float arg regs (fa0-fa7)
    try testing.expectEqual(@as(usize, 8), lp64d.float_arg_regs.len);
}

test "Riscv64ISA lowering backend" {
    const backend = Riscv64ISA.lower();

    // Should have function pointers
    try testing.expect(@intFromPtr(backend.lowerInstFn) != 0);
    try testing.expect(@intFromPtr(backend.lowerBranchFn) != 0);
}

test "Riscv64ISA compile function" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    const ctx = compile_mod.CompileCtx.init(testing.allocator, "riscv64");

    var code = try Riscv64ISA.compileFunction(ctx, &func);
    defer code.deinit();

    // Empty function produces minimal code
    try testing.expect(code.code.len == 0);
}
