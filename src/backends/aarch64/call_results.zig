const inst_mod = @import("inst.zig");
const lower_mod = @import("../../machinst/lower.zig");

const Inst = inst_mod.Inst;

pub fn emitCallResults(
    ctx: *lower_mod.LowerCtx(Inst),
    ir_inst: lower_mod.Inst,
    ret_regs: lower_mod.ValueRegs,
) !void {
    const results = ctx.func.dfg.instResults(ir_inst);
    if (results.len == 0) return;
    if (ret_regs.len() < results.len) return error.ReturnRegCountMismatch;

    for (results, 0..) |result_value, idx| {
        const src = ret_regs.get(idx) orelse return error.ReturnRegMissing;
        const ty = try ctx.getValueType(result_value);
        const class: lower_mod.RegClass = if (ty.isInt() or ty.isRef())
            .int
        else if (ty.isFloat() or ty.isVector())
            .float
        else
            return error.UnsupportedReturnType;

        const dst_vreg = try ctx.getValueReg(result_value, class);
        const dst = lower_mod.WritableReg.fromVReg(dst_vreg);

        if (ty.isFloat()) {
            const size: inst_mod.FpuOperandSize = switch (ty.bits()) {
                32 => .size32,
                64 => .size64,
                else => return error.UnsupportedReturnType,
            };
            try ctx.emit(Inst{ .fmov = .{
                .dst = dst,
                .src = src,
                .size = size,
            } });
        } else if (ty.isVector()) {
            const size: inst_mod.FpuOperandSize = switch (ty.bits()) {
                32 => .size32,
                64 => .size64,
                128 => .size128,
                else => return error.UnsupportedReturnType,
            };
            try ctx.emit(Inst{ .vec_orr = .{
                .dst = dst,
                .src1 = src,
                .src2 = src,
                .size = size,
            } });
        } else {
            const bits = ty.bits();
            const size: inst_mod.OperandSize = if (bits != 0 and bits <= 32) .size32 else .size64;
            try ctx.emit(Inst{ .mov_rr = .{
                .dst = dst,
                .src = src,
                .size = size,
            } });
        }
    }
}
