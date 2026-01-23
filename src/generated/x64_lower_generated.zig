// Generated ISLE lowering for x64
// TODO: Replace with actual ISLE-generated code when parser is complete

const std = @import("std");
const root = @import("root");
const inst_mod = @import("../backends/x64/inst.zig");
const Inst = inst_mod.Inst;
const Reg = inst_mod.Reg;
const WritableReg = inst_mod.WritableReg;
const PReg = inst_mod.PReg;
const OperandSize = inst_mod.OperandSize;
const lower_mod = @import("../machinst/lower.zig");

const Opcode = root.opcodes.Opcode;
const InstructionData = root.instruction_data.InstructionData;
const Type = root.types.Type;

// Manual lowering function until ISLE compiler is fully functional
pub fn lower(
    ctx: *lower_mod.LowerCtx(Inst),
    ir_inst: lower_mod.Inst,
) !bool {
    const inst_data = ctx.getInstData(ir_inst);

    switch (inst_data.*) {
        .unary_imm => |data| {
            if (data.opcode == .iconst) {
                const imm = data.imm.value;
                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                try ctx.emit(Inst{ .mov_imm = .{
                    .dst = dst,
                    .imm = imm,
                    .size = size,
                } });

                return true;
            }
            return false;
        },
        .binary => |data| {
            const lhs = data.args[0];
            const rhs = data.args[1];
            const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
            const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

            const lhs_reg = try ctx.getValueReg(lhs, .int);
            const rhs_reg = try ctx.getValueReg(rhs, .int);
            const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

            // x64 ALU instructions modify first operand, so copy lhs to dst first
            try ctx.emit(Inst{ .mov_rr = .{
                .dst = dst,
                .src = Reg.fromVReg(lhs_reg),
                .size = size,
            } });

            switch (data.opcode) {
                .iadd => {
                    try ctx.emit(Inst{ .add_rr = .{
                        .dst = dst,
                        .src = Reg.fromVReg(rhs_reg),
                        .size = size,
                    } });
                    return true;
                },
                .isub => {
                    try ctx.emit(Inst{ .sub_rr = .{
                        .dst = dst,
                        .src = Reg.fromVReg(rhs_reg),
                        .size = size,
                    } });
                    return true;
                },
                .band => {
                    try ctx.emit(Inst{ .and_rr = .{
                        .dst = dst,
                        .src = Reg.fromVReg(rhs_reg),
                        .size = size,
                    } });
                    return true;
                },
                .bor => {
                    try ctx.emit(Inst{ .or_rr = .{
                        .dst = dst,
                        .src = Reg.fromVReg(rhs_reg),
                        .size = size,
                    } });
                    return true;
                },
                .bxor => {
                    try ctx.emit(Inst{ .xor_rr = .{
                        .dst = dst,
                        .src = Reg.fromVReg(rhs_reg),
                        .size = size,
                    } });
                    return true;
                },
                .imul => {
                    try ctx.emit(Inst{ .imul_rr = .{
                        .dst = dst,
                        .src = Reg.fromVReg(rhs_reg),
                        .size = size,
                    } });
                    return true;
                },
                else => return false,
            }
        },
        .binary_imm64 => |data| {
            const lhs = data.arg;
            const imm = data.imm.value;
            const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
            const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

            const lhs_reg = try ctx.getValueReg(lhs, .int);
            const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

            // Copy lhs to dst
            try ctx.emit(Inst{ .mov_rr = .{
                .dst = dst,
                .src = Reg.fromVReg(lhs_reg),
                .size = size,
            } });

            // Check if immediate fits in i32
            if (imm >= std.math.minInt(i32) and imm <= std.math.maxInt(i32)) {
                const imm32: i32 = @intCast(imm);

                switch (data.opcode) {
                    .iadd_imm => {
                        try ctx.emit(Inst{ .add_imm = .{
                            .dst = dst,
                            .imm = imm32,
                            .size = size,
                        } });
                        return true;
                    },
                    .isub_imm => {
                        try ctx.emit(Inst{ .sub_imm = .{
                            .dst = dst,
                            .imm = imm32,
                            .size = size,
                        } });
                        return true;
                    },
                    else => return false,
                }
            }

            return false;
        },
        .nullary => |data| {
            if (data.opcode == .@"return") {
                try ctx.emit(Inst.ret);
                return true;
            }
            return false;
        },
        else => return false,
    }
}
