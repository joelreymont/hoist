const std = @import("std");
const root = @import("root");
const lower_mod = @import("../machinst/lower.zig");
const LowerCtx = lower_mod.LowerCtx;
const Inst = @import("../backends/riscv64/inst.zig").Inst;
const Reg = @import("../backends/riscv64/inst.zig").Reg;
const WritableReg = @import("../backends/riscv64/inst.zig").WritableReg;
const PReg = @import("../backends/riscv64/inst.zig").PReg;
const isle_impl = @import("../backends/riscv64/isle_impl.zig");
const IsleCtx = isle_impl.IsleCtx;
const Type = root.types.Type;
const condcodes = root.condcodes;

pub fn lower(ctx: *LowerCtx(Inst), inst: lower_mod.Inst) !bool {
    var isle_ctx = IsleCtx.init(ctx);
    const data = ctx.getInstData(inst);

    switch (data.*) {
        .binary => |bin_data| {
            const ty = ctx.func.dfg.instResultType(inst).?;
            const args = bin_data.args;
            const x = args[0];
            const y = args[1];

            switch (bin_data.opcode) {
                .iadd => {
                    const dst = try isle_impl.rv_add(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .isub => {
                    const dst = try isle_impl.rv_sub(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .imul => {
                    const dst = try isle_impl.rv_mul(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .sdiv => {
                    const dst = try isle_impl.rv_div(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .udiv => {
                    const dst = try isle_impl.rv_divu(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .srem => {
                    const dst = try isle_impl.rv_rem(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .urem => {
                    const dst = try isle_impl.rv_remu(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .band => {
                    const dst = try isle_impl.rv_and(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .bor => {
                    const dst = try isle_impl.rv_or(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .bxor => {
                    const dst = try isle_impl.rv_xor(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .ishl => {
                    const dst = try isle_impl.rv_sll(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .ushr => {
                    const dst = try isle_impl.rv_srl(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .sshr => {
                    const dst = try isle_impl.rv_sra(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                else => return false,
            }
        },
        .int_compare => |cmp_data| {
            const ty = ctx.func.dfg.instResultType(inst).?;
            const args = cmp_data.args;
            const x = args[0];
            const y = args[1];

            switch (cmp_data.cond) {
                .slt => {
                    const dst = try isle_impl.rv_slt(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                .ult => {
                    const dst = try isle_impl.rv_sltu(&isle_ctx, ty, x, y);
                    _ = dst;
                    return true;
                },
                else => return false,
            }
        },
        .unary => |un_data| {
            if (un_data.opcode == .@"return") {
                const ret_val = un_data.arg;
                const ret_reg = Reg.fromVReg(try ctx.getValueReg(ret_val, .int));

                // Move return value to x10 (a0) using addi
                const a0 = Reg.fromPReg(PReg.new(.int, 10));
                const dst_a0 = WritableReg.fromReg(a0);

                try ctx.emit(Inst{ .addi = .{
                    .dst = dst_a0,
                    .src = ret_reg,
                    .imm = 0,
                } });
                return true;
            }
            return false;
        },
        .nullary => |null_data| {
            if (null_data.opcode == .@"return") {
                // No-op return - epilogue handles frame cleanup
                return true;
            }
            return false;
        },
        else => return false,
    }
}
