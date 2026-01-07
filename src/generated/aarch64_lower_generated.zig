// Generated ISLE lowering for aarch64
// TODO: Replace with actual ISLE-generated code when parser is complete

const std = @import("std");
const root = @import("root");
const inst_mod = @import("../backends/aarch64/inst.zig");
const Inst = inst_mod.Inst;
const Reg = inst_mod.Reg;
const WritableReg = inst_mod.WritableReg;
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
                // Get immediate value
                const imm = data.imm.value;
                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));

                // Determine operand size from type
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Allocate output register
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                // Materialize constant using movz/movk sequence
                // For now, simple movz for small values, full sequence for larger
                const abs_imm = if (imm < 0) @as(u64, @bitCast(-imm)) else @as(u64, @intCast(imm));

                if (abs_imm <= 0xFFFF) {
                    // Single movz for 16-bit values
                    try ctx.emit(Inst{ .movz = .{
                        .dst = dst,
                        .imm = @truncate(abs_imm),
                        .shift = 0,
                        .size = size,
                    } });

                    // If negative, negate the result
                    if (imm < 0) {
                        const neg_dst = WritableReg.fromReg(dst.toReg());
                        try ctx.emit(Inst{ .neg_rr = .{
                            .dst = neg_dst,
                            .src = dst.toReg(),
                            .size = size,
                        } });
                    }
                } else {
                    // Multi-instruction sequence for larger constants
                    // movz + movk for each 16-bit chunk
                    const chunks = [_]u16{
                        @truncate(abs_imm),
                        @truncate(abs_imm >> 16),
                        @truncate(abs_imm >> 32),
                        @truncate(abs_imm >> 48),
                    };

                    var first = true;
                    for (chunks, 0..) |chunk, i| {
                        if (chunk != 0 or first) {
                            if (first) {
                                try ctx.emit(Inst{ .movz = .{
                                    .dst = dst,
                                    .imm = chunk,
                                    .shift = @intCast(i * 16),
                                    .size = size,
                                } });
                                first = false;
                            } else {
                                try ctx.emit(Inst{ .movk = .{
                                    .dst = dst,
                                    .imm = chunk,
                                    .shift = @intCast(i * 16),
                                    .size = size,
                                } });
                            }
                        }
                    }

                    if (imm < 0) {
                        const neg_dst = WritableReg.fromReg(dst.toReg());
                        try ctx.emit(Inst{ .neg_rr = .{
                            .dst = neg_dst,
                            .src = dst.toReg(),
                            .size = size,
                        } });
                    }
                }

                return true;
            }
        },
        else => {},
    }

    // Return false to indicate instruction not handled
    return false;
}
