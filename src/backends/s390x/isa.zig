const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = @import("inst.zig").Inst;
const abi_mod = @import("../../machinst/abi.zig");
const lower_mod = @import("../../machinst/lower.zig");
const compile_mod = @import("../../machinst/compile.zig");

/// s390x ISA descriptor.
/// This integrates all s390x backend components into a unified interface.
pub const S390xISA = struct {
    /// ISA name.
    pub const name = "s390x";

    /// Machine instruction type.
    pub const MachInst = Inst;

    /// ABI specification for this ISA.
    pub fn abi(call_conv: abi_mod.CallConv) abi_mod.ABIMachineSpec(u64) {
        return switch (call_conv) {
            .system_v => @import("abi.zig").sysv(),
            .aapcs64, .windows_fastcall => unreachable,
        };
    }

    /// Lowering backend for instruction selection.
    pub fn lower() lower_mod.LowerBackend(Inst) {
        return @import("lower.zig").S390xLower.backend();
    }

    /// Register information.
    pub const registers = struct {
        /// Number of general-purpose registers (r0-r15).
        pub const num_gpr: u8 = 16;
        /// Number of floating-point registers (f0-f15).
        pub const num_vec: u8 = 16;
        /// Stack pointer register.
        pub const sp_reg = 15; // r15
        /// Frame pointer register.
        pub const fp_reg = 11; // r11
        /// Link register.
        pub const lr_reg: ?u8 = 14; // r14
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
        const num_int_regs: u32 = 16; // r0-r15
        const num_float_regs: u32 = 16; // f0-f15
        const num_vector_regs: u32 = 16;

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

test "S390xISA basic properties" {
    try testing.expectEqualStrings("s390x", S390xISA.name);
    try testing.expectEqual(@as(u8, 16), S390xISA.registers.num_gpr);
    try testing.expectEqual(@as(u8, 16), S390xISA.registers.num_vec);
    try testing.expectEqual(@as(u8, 15), S390xISA.registers.sp_reg);
    try testing.expectEqual(@as(u8, 11), S390xISA.registers.fp_reg);
    try testing.expectEqual(@as(u8, 14), S390xISA.registers.lr_reg.?);
}

test "S390xISA ABI selection" {
    const sysv_abi = S390xISA.abi(.system_v);

    // s390x has 5 int arg regs (r2-r6)
    try testing.expectEqual(@as(usize, 5), sysv_abi.int_arg_regs.len);

    // s390x has 4 float arg regs (f0,f2,f4,f6)
    try testing.expectEqual(@as(usize, 4), sysv_abi.float_arg_regs.len);
}

test "S390xISA lowering backend" {
    const backend = S390xISA.lower();

    // Should have function pointers
    try testing.expect(@intFromPtr(backend.lowerInstFn) != 0);
    try testing.expect(@intFromPtr(backend.lowerBranchFn) != 0);
}

test "S390xISA compile function" {
    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    const ctx = compile_mod.CompileCtx.init(testing.allocator, "s390x");

    var code = try S390xISA.compileFunction(ctx, &func);
    defer code.deinit();

    // Empty function produces minimal code
    try testing.expect(code.code.len == 0);
}
