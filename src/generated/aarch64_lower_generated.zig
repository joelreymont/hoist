// Generated ISLE lowering for aarch64
// TODO: Replace with actual ISLE-generated code when parser is complete

const std = @import("std");
const root = @import("root");
const inst_mod = @import("../backends/aarch64/inst.zig");
const Inst = inst_mod.Inst;
const Reg = inst_mod.Reg;
const WritableReg = inst_mod.WritableReg;
const OperandSize = inst_mod.OperandSize;
const FpuOperandSize = inst_mod.FpuOperandSize;
const CondCode = inst_mod.CondCode;
const lower_mod = @import("../machinst/lower.zig");

const Opcode = root.opcodes.Opcode;
const InstructionData = root.instruction_data.InstructionData;
const Type = root.types.Type;
const IntCC = root.condcodes.IntCC;
const FloatCC = root.condcodes.FloatCC;

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
                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);

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
                        try ctx.emit(Inst{ .neg = .{
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
                        try ctx.emit(Inst{ .neg = .{
                            .dst = neg_dst,
                            .src = dst.toReg(),
                            .size = size,
                        } });
                    }
                }

                return true;
            }
        },
        .binary => |data| {
            if (data.opcode == .iadd) {
                // Get operands
                const lhs = data.args[0];
                const rhs = data.args[1];

                // Get registers for operands
                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));

                // Allocate output register
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                // Get type for size
                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Emit add instruction
                try ctx.emit(Inst{ .add_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .isub) {
                // Get operands
                const lhs = data.args[0];
                const rhs = data.args[1];

                // Get registers for operands
                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));

                // Allocate output register
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                // Get type for size
                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Emit sub instruction
                try ctx.emit(Inst{ .sub_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .imul) {
                // Get operands
                const lhs = data.args[0];
                const rhs = data.args[1];

                // Get registers for operands
                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));

                // Allocate output register
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                // Get type for size
                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Emit mul instruction
                try ctx.emit(Inst{ .mul_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .udiv) {
                // Unsigned division
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .udiv = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .sdiv) {
                // Signed division
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .sdiv = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .urem) {
                // Unsigned remainder: rem = dividend - divisor * quotient
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // quotient = udiv(lhs, rhs)
                const quotient = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{ .udiv = .{
                    .dst = quotient,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                // remainder = lhs - rhs * quotient
                try ctx.emit(Inst{ .msub = .{
                    .dst = dst,
                    .src1 = rhs_reg,
                    .src2 = quotient.toReg(),
                    .minuend = lhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .srem) {
                // Signed remainder: rem = dividend - divisor * quotient
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // quotient = sdiv(lhs, rhs)
                const quotient = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{ .sdiv = .{
                    .dst = quotient,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                // remainder = lhs - rhs * quotient
                try ctx.emit(Inst{ .msub = .{
                    .dst = dst,
                    .src1 = rhs_reg,
                    .src2 = quotient.toReg(),
                    .minuend = lhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .band) {
                // Bitwise AND
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .and_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .bor) {
                // Bitwise OR
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .orr_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .bxor) {
                // Bitwise XOR
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .eor_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .ishl) {
                // Logical shift left
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .lsl_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .ushr) {
                // Logical shift right (unsigned)
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .lsr_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .sshr) {
                // Arithmetic shift right (signed)
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .asr_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .rotr) {
                // Rotate right with register
                const src = data.args[0];
                const shift = data.args[1];

                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const shift_reg = Reg.fromVReg(try ctx.getValueReg(shift, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .ror_rr = .{
                    .dst = dst,
                    .src1 = src_reg,
                    .src2 = shift_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .rotl) {
                // Rotate left - negate shift then ror
                const src = data.args[0];
                const shift = data.args[1];

                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const shift_reg = Reg.fromVReg(try ctx.getValueReg(shift, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Negate shift amount
                const neg_shift = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{ .neg = .{
                    .dst = neg_shift,
                    .src = shift_reg,
                    .size = size,
                } });

                // Rotate right by negated shift
                try ctx.emit(Inst{ .ror_rr = .{
                    .dst = dst,
                    .src1 = src_reg,
                    .src2 = neg_shift.toReg(),
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .band_not) {
                // Bitwise AND NOT - bic instruction
                const src1 = data.args[0];
                const src2 = data.args[1];

                const src1_reg = Reg.fromVReg(try ctx.getValueReg(src1, .int));
                const src2_reg = Reg.fromVReg(try ctx.getValueReg(src2, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .bic_rr = .{
                    .dst = dst,
                    .src1 = src1_reg,
                    .src2 = src2_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .bor_not) {
                // Bitwise OR NOT - orn instruction
                const src1 = data.args[0];
                const src2 = data.args[1];

                const src1_reg = Reg.fromVReg(try ctx.getValueReg(src1, .int));
                const src2_reg = Reg.fromVReg(try ctx.getValueReg(src2, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .orn_rr = .{
                    .dst = dst,
                    .src1 = src1_reg,
                    .src2 = src2_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .bxor_not) {
                // Bitwise XOR NOT - eon instruction
                const src1 = data.args[0];
                const src2 = data.args[1];

                const src1_reg = Reg.fromVReg(try ctx.getValueReg(src1, .int));
                const src2_reg = Reg.fromVReg(try ctx.getValueReg(src2, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .eon_rr = .{
                    .dst = dst,
                    .src1 = src1_reg,
                    .src2 = src2_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .uadd_overflow) {
                // Unsigned add with overflow check
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));
                const overflow = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Emit adds to get result and set flags
                try ctx.emit(Inst{ .adds_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                // Extract carry flag (overflow for unsigned)
                try ctx.emit(Inst{
                    .cset = .{
                        .dst = overflow,
                        .cond = .cs, // carry set
                        .size = size,
                    },
                });

                return true;
            } else if (data.opcode == .sadd_overflow) {
                // Signed add with overflow check
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));
                const overflow = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Emit adds to get result and set flags
                try ctx.emit(Inst{ .adds_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                // Extract overflow flag (signed overflow)
                try ctx.emit(Inst{
                    .cset = .{
                        .dst = overflow,
                        .cond = .vs, // overflow set
                        .size = size,
                    },
                });

                return true;
            } else if (data.opcode == .usub_overflow) {
                // Unsigned subtract with overflow check
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));
                const overflow = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Emit subs to get result and set flags
                try ctx.emit(Inst{ .subs_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                // Extract borrow flag (overflow for unsigned subtract)
                try ctx.emit(Inst{
                    .cset = .{
                        .dst = overflow,
                        .cond = .cc, // carry clear (borrow)
                        .size = size,
                    },
                });

                return true;
            } else if (data.opcode == .ssub_overflow) {
                // Signed subtract with overflow check
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));
                const overflow = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Emit subs to get result and set flags
                try ctx.emit(Inst{ .subs_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                // Extract overflow flag (signed overflow)
                try ctx.emit(Inst{
                    .cset = .{
                        .dst = overflow,
                        .cond = .vs, // overflow set
                        .size = size,
                    },
                });

                return true;
            } else if (data.opcode == .fadd) {
                // Floating-point add
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .float));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(inst_mod.aarch64_fadd(dst, lhs_reg, rhs_reg, size));
                return true;
            } else if (data.opcode == .fsub) {
                // Floating-point subtract
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .float));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(inst_mod.aarch64_fsub(dst, lhs_reg, rhs_reg, size));
                return true;
            } else if (data.opcode == .fmul) {
                // Floating-point multiply
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .float));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(inst_mod.aarch64_fmul(dst, lhs_reg, rhs_reg, size));
                return true;
            } else if (data.opcode == .fdiv) {
                // Floating-point divide
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .float));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(inst_mod.aarch64_fdiv(dst, lhs_reg, rhs_reg, size));
                return true;
            } else if (data.opcode == .fmin) {
                // Floating-point minimum
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .float));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(Inst{ .fmin = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .fmax) {
                // Floating-point maximum
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .float));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(Inst{ .fmax = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .fcopysign) {
                // Copy sign bit from rhs to lhs
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .float));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                // Use bitwise operations to copy sign bit
                // For F32: sign bit is bit 31, for F64: bit 63
                // Extract magnitude from lhs (clear sign), extract sign from rhs, combine

                // Move float regs to int regs for bit manipulation
                const lhs_int = WritableReg.fromVReg(ctx.allocVReg(.int));
                const rhs_int = WritableReg.fromVReg(ctx.allocVReg(.int));

                try ctx.emit(Inst{ .fmov_to_gpr = .{
                    .dst = lhs_int,
                    .src = lhs_reg,
                    .size = size,
                } });
                try ctx.emit(Inst{ .fmov_to_gpr = .{
                    .dst = rhs_int,
                    .src = rhs_reg,
                    .size = size,
                } });

                // Create sign mask (high bit only)
                const sign_mask: u64 = if (ty.bits() == 32) 0x80000000 else 0x8000000000000000;
                const mag_mask: u64 = if (ty.bits() == 32) 0x7FFFFFFF else 0x7FFFFFFFFFFFFFFF;

                // Allocate masks
                const sign_mask_reg = WritableReg.fromVReg(ctx.allocVReg(.int));
                const mag_mask_reg = WritableReg.fromVReg(ctx.allocVReg(.int));

                // Materialize masks
                const op_size: OperandSize = if (ty.bits() == 32) .size32 else .size64;
                try ctx.emit(Inst{ .movz = .{
                    .dst = sign_mask_reg,
                    .imm = @truncate(sign_mask),
                    .shift = 0,
                    .size = op_size,
                } });
                if (ty.bits() == 64) {
                    try ctx.emit(Inst{ .movk = .{
                        .dst = sign_mask_reg,
                        .imm = @truncate(sign_mask >> 48),
                        .shift = 48,
                        .size = op_size,
                    } });
                }

                try ctx.emit(Inst{ .movz = .{
                    .dst = mag_mask_reg,
                    .imm = @truncate(mag_mask),
                    .shift = 0,
                    .size = op_size,
                } });
                if (ty.bits() == 64) {
                    for ([_]u8{ 16, 32, 48 }) |shift| {
                        try ctx.emit(Inst{ .movk = .{
                            .dst = mag_mask_reg,
                            .imm = @truncate(mag_mask >> @as(u6, @intCast(shift))),
                            .shift = shift,
                            .size = op_size,
                        } });
                    }
                }

                // Extract magnitude from lhs: lhs & mag_mask
                const mag = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{ .and_rr = .{
                    .dst = mag,
                    .src1 = lhs_int.toReg(),
                    .src2 = mag_mask_reg.toReg(),
                    .size = op_size,
                } });

                // Extract sign from rhs: rhs & sign_mask
                const sign = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{ .and_rr = .{
                    .dst = sign,
                    .src1 = rhs_int.toReg(),
                    .src2 = sign_mask_reg.toReg(),
                    .size = op_size,
                } });

                // Combine: mag | sign
                const result_int = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{ .orr_rr = .{
                    .dst = result_int,
                    .src1 = mag.toReg(),
                    .src2 = sign.toReg(),
                    .size = op_size,
                } });

                // Move back to float reg
                try ctx.emit(Inst{ .fmov_from_gpr = .{
                    .dst = dst,
                    .src = result_int.toReg(),
                    .size = size,
                } });

                return true;
            }
        },
        .load => |data| {
            if (data.opcode == .load) {
                // Get address operand
                const addr = data.arg;

                // Get register for address
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));

                // Allocate output register
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                // Get type for size
                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Emit load instruction with zero offset
                try ctx.emit(Inst{ .ldr = .{
                    .dst = dst,
                    .base = addr_reg,
                    .offset = 0,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .uload8) {
                // Load unsigned byte (zero-extend)
                const addr = data.arg;
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                // Result type determines destination size
                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .ldrb = .{
                    .dst = dst,
                    .base = addr_reg,
                    .offset = @intCast(data.offset),
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .sload8) {
                // Load signed byte (sign-extend)
                const addr = data.arg;
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .ldrsb = .{
                    .dst = dst,
                    .base = addr_reg,
                    .offset = @intCast(data.offset),
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .uload16) {
                // Load unsigned halfword (zero-extend)
                const addr = data.arg;
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .ldrh = .{
                    .dst = dst,
                    .base = addr_reg,
                    .offset = @intCast(data.offset),
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .sload16) {
                // Load signed halfword (sign-extend)
                const addr = data.arg;
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .ldrsh = .{
                    .dst = dst,
                    .base = addr_reg,
                    .offset = @intCast(data.offset),
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .uload32) {
                // Load unsigned 32-bit word (zero-extend to 64-bit)
                const addr = data.arg;
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                // Use 32-bit load which automatically zero-extends
                try ctx.emit(Inst{ .ldr = .{
                    .dst = dst,
                    .base = addr_reg,
                    .offset = @intCast(data.offset),
                    .size = .size32,
                } });

                return true;
            } else if (data.opcode == .sload32) {
                // Load signed 32-bit word (sign-extend to 64-bit)
                const addr = data.arg;
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                try ctx.emit(Inst{ .ldrsw = .{
                    .dst = dst,
                    .base = addr_reg,
                    .offset = @intCast(data.offset),
                } });

                return true;
            }
        },
        .store => |data| {
            if (data.opcode == .store) {
                // Get value and address operands
                const addr = data.args[0];
                const value = data.args[1];

                // Get registers
                const value_reg = Reg.fromVReg(try ctx.getValueReg(value, .int));
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));

                // Get type for size
                const ty = ctx.getValueType(value);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Emit store instruction with offset from StoreData
                try ctx.emit(Inst{ .str = .{
                    .src = value_reg,
                    .base = addr_reg,
                    .offset = @intCast(data.offset),
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .istore8) {
                // Store byte
                const value = data.arg;
                const addr = data.addr;

                const value_reg = Reg.fromVReg(try ctx.getValueReg(value, .int));
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));

                try ctx.emit(Inst{ .strb = .{
                    .src = value_reg,
                    .base = addr_reg,
                    .offset = @intCast(data.offset),
                } });

                return true;
            } else if (data.opcode == .istore16) {
                // Store halfword
                const value = data.arg;
                const addr = data.addr;

                const value_reg = Reg.fromVReg(try ctx.getValueReg(value, .int));
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));

                try ctx.emit(Inst{ .strh = .{
                    .src = value_reg,
                    .base = addr_reg,
                    .offset = @intCast(data.offset),
                } });

                return true;
            } else if (data.opcode == .istore32) {
                // Store 32-bit word
                const value = data.arg;
                const addr = data.addr;

                const value_reg = Reg.fromVReg(try ctx.getValueReg(value, .int));
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));

                try ctx.emit(Inst{ .str = .{
                    .src = value_reg,
                    .base = addr_reg,
                    .offset = @intCast(data.offset),
                    .size = .size32,
                } });

                return true;
            }
        },
        .unary => |data| {
            if (data.opcode == .@"return") {
                // Return with value - move to X0 return register
                const ret_val = data.arg;
                const ret_reg = Reg.fromVReg(try ctx.getValueReg(ret_val, .int));

                // Move return value to X0
                const x0 = Reg.fromPReg(inst_mod.PReg.new(.int, 0));
                const dst_x0 = WritableReg.fromReg(x0);

                // Get type for size
                const ty = ctx.getValueType(ret_val);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Emit mov to X0 if not already there
                try ctx.emit(Inst{ .mov_rr = .{
                    .dst = dst_x0,
                    .src = ret_reg,
                    .size = size,
                } });

                // Emit ret instruction
                try ctx.emit(Inst.ret);

                return true;
            } else if (data.opcode == .bnot) {
                // Bitwise NOT
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .mvn_rr = .{
                    .dst = dst,
                    .src = src_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .sextend) {
                // Sign extension
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const src_ty = ctx.getValueType(src);
                const dst_ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);

                const src_bits = src_ty.bits();
                const dst_bits = dst_ty.bits();

                // Determine destination size
                const dst_size: OperandSize = if (dst_bits <= 32) .size32 else .size64;

                // Select appropriate sign extension instruction based on source size
                if (src_bits == 8) {
                    // Sign extend byte
                    try ctx.emit(Inst{ .sxtb = .{
                        .dst = dst,
                        .src = src_reg,
                        .dst_size = dst_size,
                    } });
                } else if (src_bits == 16) {
                    // Sign extend halfword
                    try ctx.emit(Inst{ .sxth = .{
                        .dst = dst,
                        .src = src_reg,
                        .dst_size = dst_size,
                    } });
                } else if (src_bits == 32) {
                    // Sign extend word (only to 64-bit)
                    try ctx.emit(Inst{ .sxtw = .{
                        .dst = dst,
                        .src = src_reg,
                    } });
                } else {
                    // Already largest size or unsupported
                    try ctx.emit(Inst{ .mov_rr = .{
                        .dst = dst,
                        .src = src_reg,
                        .size = dst_size,
                    } });
                }

                return true;
            } else if (data.opcode == .uextend) {
                // Zero/unsigned extension
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const src_ty = ctx.getValueType(src);
                const dst_ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);

                const src_bits = src_ty.bits();
                const dst_bits = dst_ty.bits();

                const dst_size: OperandSize = if (dst_bits <= 32) .size32 else .size64;

                // Select appropriate zero extension instruction based on source size
                if (src_bits == 8) {
                    // Zero extend byte
                    try ctx.emit(Inst{ .uxtb = .{
                        .dst = dst,
                        .src = src_reg,
                        .dst_size = dst_size,
                    } });
                } else if (src_bits == 16) {
                    // Zero extend halfword
                    try ctx.emit(Inst{ .uxth = .{
                        .dst = dst,
                        .src = src_reg,
                        .dst_size = dst_size,
                    } });
                } else if (src_bits == 32 and dst_bits == 64) {
                    // Zero extend word to 64-bit (32-bit ops auto zero-extend in ARM64)
                    // Just use a 32-bit mov which zero-extends
                    try ctx.emit(Inst{ .mov_rr = .{
                        .dst = dst,
                        .src = src_reg,
                        .size = .size32,
                    } });
                } else {
                    // No-op or unsupported
                    try ctx.emit(Inst{ .mov_rr = .{
                        .dst = dst,
                        .src = src_reg,
                        .size = dst_size,
                    } });
                }

                return true;
            } else if (data.opcode == .ireduce) {
                // Integer reduce (truncate to smaller type)
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const dst_ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const dst_bits = dst_ty.bits();

                // Determine size for move
                const size: OperandSize = if (dst_bits <= 32) .size32 else .size64;

                // For reduction, just move with appropriate size
                // Lower bits are preserved, upper bits discarded
                try ctx.emit(Inst{ .mov_rr = .{
                    .dst = dst,
                    .src = src_reg,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .clz) {
                // Count leading zeros
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .clz = .{
                    .dst = dst,
                    .src = src_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .ctz) {
                // Count trailing zeros - rbit then clz
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .ctz = .{
                    .dst = dst,
                    .src = src_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .popcnt) {
                // Population count
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .popcnt = .{
                    .dst = dst,
                    .src = src_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .bitrev) {
                // Reverse bits
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .rbit = .{
                    .dst = dst,
                    .src = src_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .bswap) {
                // Byte swap
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);

                // Choose rev instruction based on type width
                if (ty.bits() == 16) {
                    try ctx.emit(Inst{ .rev16 = .{
                        .dst = dst,
                        .src = src_reg,
                        .size = .size32,
                    } });
                } else if (ty.bits() == 32) {
                    try ctx.emit(Inst{ .rev32 = .{
                        .dst = dst,
                        .src = src_reg,
                        .size = .size64,
                    } });
                } else if (ty.bits() == 64) {
                    try ctx.emit(Inst{ .rev64 = .{
                        .dst = dst,
                        .src = src_reg,
                    } });
                } else {
                    return false;
                }
                return true;
            } else if (data.opcode == .fabs) {} else if (data.opcode == .fabs) {
                // Floating-point absolute value
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(inst_mod.aarch64_fabs(dst, src_reg, size));
                return true;
            } else if (data.opcode == .fneg) {
                // Floating-point negate
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(inst_mod.aarch64_fneg(dst, src_reg, size));
                return true;
            } else if (data.opcode == .sqrt) {
                // Floating-point square root
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(inst_mod.aarch64_fsqrt(dst, src_reg, size));
                return true;
            } else if (data.opcode == .ceil) {
                // Floating-point round toward positive infinity
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(Inst{ .frintp = .{
                    .dst = dst,
                    .src = src_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .floor) {
                // Floating-point round toward negative infinity
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(Inst{ .frintm = .{
                    .dst = dst,
                    .src = src_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .trunc) {
                // Floating-point round toward zero
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(Inst{ .frintz = .{
                    .dst = dst,
                    .src = src_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .nearest) {
                // Floating-point round to nearest, ties to even
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(Inst{ .frintn = .{
                    .dst = dst,
                    .src = src_reg,
                    .size = size,
                } });
                return true;
            } else if (data.opcode == .fcvt_to_sint) {
                // Convert float to signed integer
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                // Get source float type
                const src_ty = ctx.getValueType(src);
                const src_size: FpuOperandSize = if (src_ty.bits() == 32) .size32 else .size64;

                // Get destination integer type
                const dst_ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const dst_size: OperandSize = if (dst_ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .fcvtzs = .{
                    .dst = dst,
                    .src = src_reg,
                    .src_size = src_size,
                    .dst_size = dst_size,
                } });
                return true;
            } else if (data.opcode == .fcvt_to_uint) {
                // Convert float to unsigned integer
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                // Get source float type
                const src_ty = ctx.getValueType(src);
                const src_size: FpuOperandSize = if (src_ty.bits() == 32) .size32 else .size64;

                // Get destination integer type
                const dst_ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const dst_size: OperandSize = if (dst_ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .fcvtzu = .{
                    .dst = dst,
                    .src = src_reg,
                    .src_size = src_size,
                    .dst_size = dst_size,
                } });
                return true;
            } else if (data.opcode == .fcvt_from_sint) {
                // Convert signed integer to float
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                // Get source integer type
                const src_ty = ctx.getValueType(src);
                const src_size: OperandSize = if (src_ty.bits() <= 32) .size32 else .size64;

                // Get destination float type
                const dst_ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const dst_size: FpuOperandSize = if (dst_ty.bits() == 32) .size32 else .size64;

                try ctx.emit(Inst{ .scvtf = .{
                    .dst = dst,
                    .src = src_reg,
                    .src_size = src_size,
                    .dst_size = dst_size,
                } });
                return true;
            } else if (data.opcode == .fcvt_from_uint) {
                // Convert unsigned integer to float
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                // Get source integer type
                const src_ty = ctx.getValueType(src);
                const src_size: OperandSize = if (src_ty.bits() <= 32) .size32 else .size64;

                // Get destination float type
                const dst_ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const dst_size: FpuOperandSize = if (dst_ty.bits() == 32) .size32 else .size64;

                try ctx.emit(Inst{ .ucvtf = .{
                    .dst = dst,
                    .src = src_reg,
                    .src_size = src_size,
                    .dst_size = dst_size,
                } });
                return true;
            } else if (data.opcode == .fcvt_to_sint_sat) {
                // Convert float to signed integer with saturation
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));

                // Get source float type
                const src_ty = ctx.getValueType(src);
                const src_size: FpuOperandSize = if (src_ty.bits() == 32) .size32 else .size64;

                // Get destination integer type
                const dst_ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const dst_size: OperandSize = if (dst_ty.bits() <= 32) .size32 else .size64;

                // Do initial conversion
                const result = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{ .fcvtzs = .{
                    .dst = result,
                    .src = src_reg,
                    .src_size = src_size,
                    .dst_size = dst_size,
                } });

                // For I32/I64, ARM64 fcvtzs already saturates - we're done
                if (dst_ty.bits() >= 32) {
                    return true;
                }

                // For I8/I16, clamp to [signed_min, signed_max]
                const result_reg = Reg.fromVReg(result.toVReg());

                // Load max value for the target type
                const max_val: u64 = if (dst_ty.bits() == 8) 0x7F else 0x7FFF;
                const max_reg = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(inst_mod.aarch64_movz(max_reg, max_val, 0, .size32));

                // Load min value (sign-extended)
                const min_val: u64 = if (dst_ty.bits() == 8) 0xFF80 else 0xFFFF8000;
                const min_reg = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(inst_mod.aarch64_movn(min_reg, ~min_val & 0xFFFF, 0, .size32));

                // Clamp to max: if result > max, use max
                const clamped1 = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{
                    .subs = .{
                        .dst = WritableReg.fromVReg(ctx.allocVReg(.int)), // discard flags
                        .src1 = result_reg,
                        .src2 = Reg.fromVReg(max_reg.toVReg()),
                        .size = dst_size,
                    },
                });
                try ctx.emit(Inst{ .csel = .{
                    .dst = clamped1,
                    .cond = CondCode.gt,
                    .if_true = Reg.fromVReg(max_reg.toVReg()),
                    .if_false = result_reg,
                } });

                // Clamp to min: if result < min, use min
                const clamped2 = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{
                    .subs = .{
                        .dst = WritableReg.fromVReg(ctx.allocVReg(.int)), // discard flags
                        .src1 = Reg.fromVReg(clamped1.toVReg()),
                        .src2 = Reg.fromVReg(min_reg.toVReg()),
                        .size = dst_size,
                    },
                });
                try ctx.emit(Inst{ .csel = .{
                    .dst = clamped2,
                    .cond = CondCode.lt,
                    .if_true = Reg.fromVReg(min_reg.toVReg()),
                    .if_false = Reg.fromVReg(clamped1.toVReg()),
                } });

                return true;
            } else if (data.opcode == .fcvt_to_uint_sat) {
                // Convert float to unsigned integer with saturation
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));

                // Get source float type
                const src_ty = ctx.getValueType(src);
                const src_size: FpuOperandSize = if (src_ty.bits() == 32) .size32 else .size64;

                // Get destination integer type
                const dst_ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const dst_size: OperandSize = if (dst_ty.bits() <= 32) .size32 else .size64;

                // Do initial conversion
                const result = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{ .fcvtzu = .{
                    .dst = result,
                    .src = src_reg,
                    .src_size = src_size,
                    .dst_size = dst_size,
                } });

                // For I32/I64, ARM64 fcvtzu already saturates - we're done
                if (dst_ty.bits() >= 32) {
                    return true;
                }

                // For I8/I16, clamp to [0, unsigned_max]
                const result_reg = Reg.fromVReg(result.toVReg());

                // Load max value for the target type (zero-extend)
                const max_val: u64 = if (dst_ty.bits() == 8) 0xFF else 0xFFFF;
                const max_reg = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(inst_mod.aarch64_movz(max_reg, max_val, 0, .size32));

                // Clamp to max: if result > max, use max
                const clamped = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{
                    .subs = .{
                        .dst = WritableReg.fromVReg(ctx.allocVReg(.int)), // discard flags
                        .src1 = result_reg,
                        .src2 = Reg.fromVReg(max_reg.toVReg()),
                        .size = .size32,
                    },
                });
                try ctx.emit(Inst{
                    .csel = .{
                        .dst = clamped,
                        .cond = CondCode.hi, // unsigned higher
                        .if_true = Reg.fromVReg(max_reg.toVReg()),
                        .if_false = result_reg,
                    },
                });

                return true;
            } else if (data.opcode == .fpromote) {
                // Promote F32 to F64
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                try ctx.emit(Inst{ .fcvt_f32_to_f64 = .{
                    .dst = dst,
                    .src = src_reg,
                } });
                return true;
            } else if (data.opcode == .fdemote) {
                // Demote F64 to F32
                const src = data.arg;
                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                try ctx.emit(Inst{ .fcvt_f64_to_f32 = .{
                    .dst = dst,
                    .src = src_reg,
                } });
                return true;
            }
        },
        .nullary => |data| {
            if (data.opcode == .@"return") {
                // Void return - just emit ret instruction
                try ctx.emit(Inst.ret);
                return true;
            } else if (data.opcode == .trap) {
                // Unconditional trap - emit udf instruction
                try ctx.emit(Inst{ .udf = .{ .imm = 0 } });
                return true;
            } else if (data.opcode == .get_frame_pointer) {
                // Get frame pointer (x29)
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));
                const fp_reg = Reg.fromPReg(Reg.fromInt(29)); // X29 (FP)

                try ctx.emit(Inst{ .mov_rr = .{
                    .dst = dst,
                    .src = fp_reg,
                    .size = .size64,
                } });
                return true;
            } else if (data.opcode == .get_stack_pointer) {
                // Get stack pointer (sp/x31)
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));
                const sp_reg = Reg.fromPReg(Reg.fromInt(31)); // SP

                try ctx.emit(Inst{ .mov_rr = .{
                    .dst = dst,
                    .src = sp_reg,
                    .size = .size64,
                } });
                return true;
            } else if (data.opcode == .get_pinned_reg) {
                // Get pinned register (x18 - platform register)
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));
                const pinned_reg = Reg.fromPReg(Reg.fromInt(18)); // X18

                try ctx.emit(Inst{ .mov_rr = .{
                    .dst = dst,
                    .src = pinned_reg,
                    .size = .size64,
                } });
                return true;
            }
        },
        .unary_with_trap => |data| {
            if (data.opcode == .trapz) {
                // Trap if zero
                const arg = data.arg;
                const arg_reg = Reg.fromVReg(try ctx.getValueReg(arg, .int));

                // Compare arg to zero
                try ctx.emit(Inst{ .cmp_imm = .{
                    .src = arg_reg,
                    .imm = 0,
                    .size = .size64,
                } });

                // Create trap block label
                const trap_label = ctx.allocLabel();

                // Branch to trap if equal (zero)
                try ctx.emit(Inst{ .b_cond = .{
                    .cond = .eq,
                    .target = .{ .label = trap_label },
                } });

                // Emit trap code
                try ctx.emitLabel(trap_label);
                try ctx.emit(Inst{ .udf = .{ .imm = 0 } });

                return true;
            } else if (data.opcode == .trapnz) {
                // Trap if not zero
                const arg = data.arg;
                const arg_reg = Reg.fromVReg(try ctx.getValueReg(arg, .int));

                // Compare arg to zero
                try ctx.emit(Inst{ .cmp_imm = .{
                    .src = arg_reg,
                    .imm = 0,
                    .size = .size64,
                } });

                // Create trap block label
                const trap_label = ctx.allocLabel();

                // Branch to trap if not equal (not zero)
                try ctx.emit(Inst{ .b_cond = .{
                    .cond = .ne,
                    .target = .{ .label = trap_label },
                } });

                // Emit trap code
                try ctx.emitLabel(trap_label);
                try ctx.emit(Inst{ .udf = .{ .imm = 0 } });

                return true;
            }
        },
        .jump => |data| {
            if (data.opcode == .jump) {
                // Unconditional jump to destination block
                const target_label = try ctx.getBlockLabel(data.destination);
                try ctx.emit(Inst{ .b = .{
                    .target = .{ .label = target_label },
                } });
                return true;
            }
        },
        .branch => |data| {
            if (data.opcode == .brif) {
                // Conditional branch: if condition then then_dest else else_dest
                const cond_val = data.condition;
                const cond_reg = Reg.fromVReg(try ctx.getValueReg(cond_val, .int));

                // Get target labels
                const then_label = try ctx.getBlockLabel(data.then_dest.?);
                const else_label = try ctx.getBlockLabel(data.else_dest.?);

                // Compare condition to zero
                try ctx.emit(Inst{ .cmp_imm = .{
                    .src = cond_reg,
                    .imm = 0,
                    .size = .size64,
                } });

                // Branch if not equal (condition != 0) to then block
                try ctx.emit(Inst{ .b_cond = .{
                    .cond = .ne,
                    .target = .{ .label = then_label },
                } });

                // Fall through or jump to else block
                try ctx.emit(Inst{ .b = .{
                    .target = .{ .label = else_label },
                } });

                return true;
            }
        },
        .int_compare => |data| {
            if (data.opcode == .icmp) {
                // Integer comparison: compare two registers
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Map IntCC to ARM64 CondCode
                const cond: CondCode = switch (data.cond) {
                    .eq => .eq, // equal
                    .ne => .ne, // not equal
                    .slt => .lt, // signed less than
                    .sge => .ge, // signed greater or equal
                    .sgt => .gt, // signed greater than
                    .sle => .le, // signed less or equal
                    .ult => .cc, // unsigned less than (carry clear)
                    .uge => .cs, // unsigned greater or equal (carry set)
                    .ugt => .hi, // unsigned higher
                    .ule => .ls, // unsigned lower or same
                };

                // Emit cmp instruction
                try ctx.emit(Inst{ .cmp_rr = .{
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                // Emit cset instruction to materialize result in register
                try ctx.emit(Inst{ .cset = .{
                    .dst = dst,
                    .cond = cond,
                    .size = size,
                } });

                return true;
            }
        },
        .int_compare_imm => |data| {
            if (data.opcode == .icmp_imm) {
                // Integer comparison with immediate
                const lhs = data.arg;
                const imm = data.imm.value;

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Map IntCC to ARM64 CondCode
                const cond: CondCode = switch (data.cond) {
                    .eq => .eq,
                    .ne => .ne,
                    .slt => .lt,
                    .sge => .ge,
                    .sgt => .gt,
                    .sle => .le,
                    .ult => .cc,
                    .uge => .cs,
                    .ugt => .hi,
                    .ule => .ls,
                };

                // Check if immediate fits in 12-bit encoding
                // ARM64 cmp_imm uses Imm12 which must be 0-4095
                if (imm >= 0 and imm <= 4095) {
                    // Emit cmp immediate instruction
                    try ctx.emit(Inst{ .cmp_imm = .{
                        .src = lhs_reg,
                        .imm = @intCast(imm),
                        .size = size,
                    } });
                } else {
                    // Immediate doesn't fit - materialize in register first
                    const imm_reg = WritableReg.fromVReg(ctx.allocVReg(.int));
                    const imm_abs = if (imm < 0) @as(u64, @bitCast(-imm)) else @as(u64, @intCast(imm));

                    // Materialize immediate (simplified for now)
                    if (imm_abs <= 0xFFFF) {
                        try ctx.emit(Inst{ .movz = .{
                            .dst = imm_reg,
                            .imm = @truncate(imm_abs),
                            .shift = 0,
                            .size = size,
                        } });
                        if (imm < 0) {
                            const neg_dst = WritableReg.fromReg(imm_reg.toReg());
                            try ctx.emit(Inst{ .neg = .{
                                .dst = neg_dst,
                                .src = imm_reg.toReg(),
                                .size = size,
                            } });
                        }
                    } else {
                        // Full constant materialization
                        const chunks = [_]u16{
                            @truncate(imm_abs),
                            @truncate(imm_abs >> 16),
                            @truncate(imm_abs >> 32),
                            @truncate(imm_abs >> 48),
                        };

                        var first = true;
                        for (chunks, 0..) |chunk, i| {
                            if (chunk != 0 or first) {
                                if (first) {
                                    try ctx.emit(Inst{ .movz = .{
                                        .dst = imm_reg,
                                        .imm = chunk,
                                        .shift = @intCast(i * 16),
                                        .size = size,
                                    } });
                                    first = false;
                                } else {
                                    try ctx.emit(Inst{ .movk = .{
                                        .dst = imm_reg,
                                        .imm = chunk,
                                        .shift = @intCast(i * 16),
                                        .size = size,
                                    } });
                                }
                            }
                        }

                        if (imm < 0) {
                            const neg_dst = WritableReg.fromReg(imm_reg.toReg());
                            try ctx.emit(Inst{ .neg = .{
                                .dst = neg_dst,
                                .src = imm_reg.toReg(),
                                .size = size,
                            } });
                        }
                    }

                    // Now compare with register
                    try ctx.emit(Inst{ .cmp_rr = .{
                        .src1 = lhs_reg,
                        .src2 = imm_reg.toReg(),
                        .size = size,
                    } });
                }

                // Emit cset instruction to materialize result
                try ctx.emit(Inst{ .cset = .{
                    .dst = dst,
                    .cond = cond,
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .iadd_imm) {
                // Integer add with immediate
                const src = data.arg;
                const imm = data.imm.value;

                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Check if immediate fits in 12-bit encoding (0-4095)
                if (imm >= 0 and imm <= 4095) {
                    try ctx.emit(Inst{ .add_imm = .{
                        .dst = dst,
                        .src = src_reg,
                        .imm = @intCast(imm),
                        .size = size,
                    } });
                } else {
                    // Materialize immediate in register and use add_rr
                    const imm_reg = WritableReg.fromVReg(ctx.allocVReg(.int));
                    const imm_abs = if (imm < 0) @as(u64, @bitCast(-imm)) else @as(u64, @intCast(imm));

                    if (imm_abs <= 0xFFFF) {
                        try ctx.emit(Inst{ .movz = .{
                            .dst = imm_reg,
                            .imm = @truncate(imm_abs),
                            .shift = 0,
                            .size = size,
                        } });
                        if (imm < 0) {
                            const neg_dst = WritableReg.fromReg(imm_reg.toReg());
                            try ctx.emit(Inst{ .neg = .{
                                .dst = neg_dst,
                                .src = imm_reg.toReg(),
                                .size = size,
                            } });
                        }
                    } else {
                        // Multi-chunk materialization
                        const chunks = [_]u16{
                            @truncate(imm_abs),
                            @truncate(imm_abs >> 16),
                            @truncate(imm_abs >> 32),
                            @truncate(imm_abs >> 48),
                        };

                        var first = true;
                        for (chunks, 0..) |chunk, i| {
                            if (chunk != 0 or first) {
                                if (first) {
                                    try ctx.emit(Inst{ .movz = .{
                                        .dst = imm_reg,
                                        .imm = chunk,
                                        .shift = @intCast(i * 16),
                                        .size = size,
                                    } });
                                    first = false;
                                } else {
                                    try ctx.emit(Inst{ .movk = .{
                                        .dst = imm_reg,
                                        .imm = chunk,
                                        .shift = @intCast(i * 16),
                                        .size = size,
                                    } });
                                }
                            }
                        }

                        if (imm < 0) {
                            const neg_dst = WritableReg.fromReg(imm_reg.toReg());
                            try ctx.emit(Inst{ .neg = .{
                                .dst = neg_dst,
                                .src = imm_reg.toReg(),
                                .size = size,
                            } });
                        }
                    }

                    // Emit add with register
                    try ctx.emit(Inst{ .add_rr = .{
                        .dst = dst,
                        .src1 = src_reg,
                        .src2 = imm_reg.toReg(),
                        .size = size,
                    } });
                }

                return true;
            } else if (data.opcode == .isub_imm) {
                // Integer subtract with immediate
                const src = data.arg;
                const imm = data.imm.value;

                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Check if immediate fits in 12-bit encoding (0-4095)
                if (imm >= 0 and imm <= 4095) {
                    try ctx.emit(Inst{ .sub_imm = .{
                        .dst = dst,
                        .src = src_reg,
                        .imm = @intCast(imm),
                        .size = size,
                    } });
                } else {
                    // Materialize immediate and use sub_rr
                    const imm_reg = WritableReg.fromVReg(ctx.allocVReg(.int));
                    const imm_abs = if (imm < 0) @as(u64, @bitCast(-imm)) else @as(u64, @intCast(imm));

                    if (imm_abs <= 0xFFFF) {
                        try ctx.emit(Inst{ .movz = .{
                            .dst = imm_reg,
                            .imm = @truncate(imm_abs),
                            .shift = 0,
                            .size = size,
                        } });
                        if (imm < 0) {
                            const neg_dst = WritableReg.fromReg(imm_reg.toReg());
                            try ctx.emit(Inst{ .neg = .{
                                .dst = neg_dst,
                                .src = imm_reg.toReg(),
                                .size = size,
                            } });
                        }
                    } else {
                        // Multi-chunk materialization
                        const chunks = [_]u16{
                            @truncate(imm_abs),
                            @truncate(imm_abs >> 16),
                            @truncate(imm_abs >> 32),
                            @truncate(imm_abs >> 48),
                        };

                        var first = true;
                        for (chunks, 0..) |chunk, i| {
                            if (chunk != 0 or first) {
                                if (first) {
                                    try ctx.emit(Inst{ .movz = .{
                                        .dst = imm_reg,
                                        .imm = chunk,
                                        .shift = @intCast(i * 16),
                                        .size = size,
                                    } });
                                    first = false;
                                } else {
                                    try ctx.emit(Inst{ .movk = .{
                                        .dst = imm_reg,
                                        .imm = chunk,
                                        .shift = @intCast(i * 16),
                                        .size = size,
                                    } });
                                }
                            }
                        }

                        if (imm < 0) {
                            const neg_dst = WritableReg.fromReg(imm_reg.toReg());
                            try ctx.emit(Inst{ .neg = .{
                                .dst = neg_dst,
                                .src = imm_reg.toReg(),
                                .size = size,
                            } });
                        }
                    }

                    // Emit sub with register
                    try ctx.emit(Inst{ .sub_rr = .{
                        .dst = dst,
                        .src1 = src_reg,
                        .src2 = imm_reg.toReg(),
                        .size = size,
                    } });
                }

                return true;
            } else if (data.opcode == .band_imm) {
                // Bitwise AND with immediate
                const src = data.arg;
                const imm = data.imm.value;

                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Try to use and_imm with logical immediate encoding
                const imm_u64 = @as(u64, @bitCast(imm));
                if (inst_mod.aarch64_and_imm(dst, src_reg, imm_u64, size)) |inst| {
                    try ctx.emit(inst);
                } else {
                    // Immediate not encodable - materialize and use and_rr
                    const imm_reg = WritableReg.fromVReg(ctx.allocVReg(.int));
                    const imm_abs = if (imm < 0) @as(u64, @bitCast(-imm)) else @as(u64, @intCast(imm));

                    if (imm_abs <= 0xFFFF) {
                        try ctx.emit(Inst{ .movz = .{
                            .dst = imm_reg,
                            .imm = @truncate(imm_abs),
                            .shift = 0,
                            .size = size,
                        } });
                        if (imm < 0) {
                            const neg_dst = WritableReg.fromReg(imm_reg.toReg());
                            try ctx.emit(Inst{ .neg = .{
                                .dst = neg_dst,
                                .src = imm_reg.toReg(),
                                .size = size,
                            } });
                        }
                    } else {
                        const chunks = [_]u16{
                            @truncate(imm_abs),
                            @truncate(imm_abs >> 16),
                            @truncate(imm_abs >> 32),
                            @truncate(imm_abs >> 48),
                        };

                        var first = true;
                        for (chunks, 0..) |chunk, i| {
                            if (chunk != 0 or first) {
                                if (first) {
                                    try ctx.emit(Inst{ .movz = .{
                                        .dst = imm_reg,
                                        .imm = chunk,
                                        .shift = @intCast(i * 16),
                                        .size = size,
                                    } });
                                    first = false;
                                } else {
                                    try ctx.emit(Inst{ .movk = .{
                                        .dst = imm_reg,
                                        .imm = chunk,
                                        .shift = @intCast(i * 16),
                                        .size = size,
                                    } });
                                }
                            }
                        }

                        if (imm < 0) {
                            const neg_dst = WritableReg.fromReg(imm_reg.toReg());
                            try ctx.emit(Inst{ .neg = .{
                                .dst = neg_dst,
                                .src = imm_reg.toReg(),
                                .size = size,
                            } });
                        }
                    }

                    try ctx.emit(Inst{ .and_rr = .{
                        .dst = dst,
                        .src1 = src_reg,
                        .src2 = imm_reg.toReg(),
                        .size = size,
                    } });
                }

                return true;
            } else if (data.opcode == .bor_imm) {
                // Bitwise OR with immediate
                const src = data.arg;
                const imm = data.imm.value;

                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                const imm_u64 = @as(u64, @bitCast(imm));
                if (inst_mod.aarch64_orr_imm(dst, src_reg, imm_u64, size)) |inst| {
                    try ctx.emit(inst);
                } else {
                    // Materialize and use orr_rr
                    const imm_reg = WritableReg.fromVReg(ctx.allocVReg(.int));
                    const imm_abs = if (imm < 0) @as(u64, @bitCast(-imm)) else @as(u64, @intCast(imm));

                    if (imm_abs <= 0xFFFF) {
                        try ctx.emit(Inst{ .movz = .{
                            .dst = imm_reg,
                            .imm = @truncate(imm_abs),
                            .shift = 0,
                            .size = size,
                        } });
                        if (imm < 0) {
                            const neg_dst = WritableReg.fromReg(imm_reg.toReg());
                            try ctx.emit(Inst{ .neg = .{
                                .dst = neg_dst,
                                .src = imm_reg.toReg(),
                                .size = size,
                            } });
                        }
                    } else {
                        const chunks = [_]u16{
                            @truncate(imm_abs),
                            @truncate(imm_abs >> 16),
                            @truncate(imm_abs >> 32),
                            @truncate(imm_abs >> 48),
                        };

                        var first = true;
                        for (chunks, 0..) |chunk, i| {
                            if (chunk != 0 or first) {
                                if (first) {
                                    try ctx.emit(Inst{ .movz = .{
                                        .dst = imm_reg,
                                        .imm = chunk,
                                        .shift = @intCast(i * 16),
                                        .size = size,
                                    } });
                                    first = false;
                                } else {
                                    try ctx.emit(Inst{ .movk = .{
                                        .dst = imm_reg,
                                        .imm = chunk,
                                        .shift = @intCast(i * 16),
                                        .size = size,
                                    } });
                                }
                            }
                        }

                        if (imm < 0) {
                            const neg_dst = WritableReg.fromReg(imm_reg.toReg());
                            try ctx.emit(Inst{ .neg = .{
                                .dst = neg_dst,
                                .src = imm_reg.toReg(),
                                .size = size,
                            } });
                        }
                    }

                    try ctx.emit(Inst{ .orr_rr = .{
                        .dst = dst,
                        .src1 = src_reg,
                        .src2 = imm_reg.toReg(),
                        .size = size,
                    } });
                }

                return true;
            } else if (data.opcode == .bxor_imm) {
                // Bitwise XOR with immediate
                const src = data.arg;
                const imm = data.imm.value;

                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                const imm_u64 = @as(u64, @bitCast(imm));
                if (inst_mod.aarch64_eor_imm(dst, src_reg, imm_u64, size)) |inst| {
                    try ctx.emit(inst);
                } else {
                    // Materialize and use eor_rr
                    const imm_reg = WritableReg.fromVReg(ctx.allocVReg(.int));
                    const imm_abs = if (imm < 0) @as(u64, @bitCast(-imm)) else @as(u64, @intCast(imm));

                    if (imm_abs <= 0xFFFF) {
                        try ctx.emit(Inst{ .movz = .{
                            .dst = imm_reg,
                            .imm = @truncate(imm_abs),
                            .shift = 0,
                            .size = size,
                        } });
                        if (imm < 0) {
                            const neg_dst = WritableReg.fromReg(imm_reg.toReg());
                            try ctx.emit(Inst{ .neg = .{
                                .dst = neg_dst,
                                .src = imm_reg.toReg(),
                                .size = size,
                            } });
                        }
                    } else {
                        const chunks = [_]u16{
                            @truncate(imm_abs),
                            @truncate(imm_abs >> 16),
                            @truncate(imm_abs >> 32),
                            @truncate(imm_abs >> 48),
                        };

                        var first = true;
                        for (chunks, 0..) |chunk, i| {
                            if (chunk != 0 or first) {
                                if (first) {
                                    try ctx.emit(Inst{ .movz = .{
                                        .dst = imm_reg,
                                        .imm = chunk,
                                        .shift = @intCast(i * 16),
                                        .size = size,
                                    } });
                                    first = false;
                                } else {
                                    try ctx.emit(Inst{ .movk = .{
                                        .dst = imm_reg,
                                        .imm = chunk,
                                        .shift = @intCast(i * 16),
                                        .size = size,
                                    } });
                                }
                            }
                        }

                        if (imm < 0) {
                            const neg_dst = WritableReg.fromReg(imm_reg.toReg());
                            try ctx.emit(Inst{ .neg = .{
                                .dst = neg_dst,
                                .src = imm_reg.toReg(),
                                .size = size,
                            } });
                        }
                    }

                    try ctx.emit(Inst{ .eor_rr = .{
                        .dst = dst,
                        .src1 = src_reg,
                        .src2 = imm_reg.toReg(),
                        .size = size,
                    } });
                }

                return true;
            } else if (data.opcode == .ishl_imm) {
                // Logical shift left with immediate
                const src = data.arg;
                const shift = @as(u8, @intCast(data.imm.value & 0x3F)); // Mask to 6 bits

                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(inst_mod.aarch64_lsl(dst, src_reg, shift, size));
                return true;
            } else if (data.opcode == .ushr_imm) {
                // Logical shift right with immediate
                const src = data.arg;
                const shift = @as(u8, @intCast(data.imm.value & 0x3F));

                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(inst_mod.aarch64_lsr(dst, src_reg, shift, size));
                return true;
            } else if (data.opcode == .sshr_imm) {
                // Arithmetic shift right with immediate
                const src = data.arg;
                const shift = @as(u8, @intCast(data.imm.value & 0x3F));

                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(inst_mod.aarch64_asr(dst, src_reg, shift, size));
                return true;
            }
        },
        .binary_imm64 => |data| {
            if (data.opcode == .rotr_imm) {
                // Rotate right with immediate
                const src = data.arg;
                const shift = @as(u8, @intCast(data.imm.value & 0x3F));

                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(inst_mod.aarch64_ror(dst, src_reg, shift, size));
                return true;
            } else if (data.opcode == .rotl_imm) {
                // Rotate left with immediate - ror with (width - shift)
                const src = data.arg;
                const shift_left = data.imm.value;

                const src_reg = Reg.fromVReg(try ctx.getValueReg(src, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Convert left shift to right shift: ror by (width - shift)
                const width: i64 = if (ty.bits() <= 32) 32 else 64;
                const shift_right = @as(u8, @intCast((width - shift_left) & 0x3F));

                try ctx.emit(inst_mod.aarch64_ror(dst, src_reg, shift_right, size));
                return true;
            }
        },
        .stack_load => |data| {
            if (data.opcode == .stack_load) {
                // Load from stack slot at FP + offset
                const stack_slot = data.stack_slot;
                const offset = data.offset;

                // Get stack slot data from function
                const slot_data = ctx.func.stack_slots.get(stack_slot) orelse return false;

                // Calculate FP-relative offset
                // Stack slots are allocated relative to FP
                // TODO: This needs frame layout to compute actual offset
                const fp_offset = offset;

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));
                const fp_reg = Reg.fromPReg(Reg.fromInt(29)); // X29 (FP)

                // Emit ldr with FP-relative addressing
                try ctx.emit(Inst{ .ldr = .{
                    .dst = dst,
                    .base = fp_reg,
                    .offset = fp_offset,
                    .size = size,
                } });

                _ = slot_data; // TODO: Use slot_data for size/alignment checks
                return true;
            } else if (data.opcode == .stack_addr) {
                // Compute address of stack slot: FP + offset
                const stack_slot = data.stack_slot;
                const offset = data.offset;

                // Get stack slot data from function
                const slot_data = ctx.func.stack_slots.get(stack_slot) orelse return false;

                // Calculate FP-relative offset
                const fp_offset = offset;

                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));
                const fp_reg = Reg.fromPReg(Reg.fromInt(29)); // X29 (FP)

                // Emit add to compute address
                if (fp_offset == 0) {
                    // Just move FP to dst
                    try ctx.emit(Inst{ .mov_rr = .{
                        .dst = dst,
                        .src = fp_reg,
                        .size = .size64,
                    } });
                } else {
                    try ctx.emit(Inst{ .add_imm = .{
                        .dst = dst,
                        .src = fp_reg,
                        .imm = @intCast(fp_offset),
                        .size = .size64,
                    } });
                }

                _ = slot_data; // TODO: Use slot_data for size/alignment checks
                return true;
            }
        },
        .stack_store => |data| {
            if (data.opcode == .stack_store) {
                // Store to stack slot at FP + offset
                const value = data.arg;
                const stack_slot = data.stack_slot;
                const offset = data.offset;

                // Get stack slot data from function
                const slot_data = ctx.func.stack_slots.get(stack_slot) orelse return false;

                // Calculate FP-relative offset
                const fp_offset = offset;

                const ty = ctx.getValueType(value);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                const value_reg = Reg.fromVReg(try ctx.getValueReg(value, .int));
                const fp_reg = Reg.fromPReg(Reg.fromInt(29)); // X29 (FP)

                // Emit str with FP-relative addressing
                try ctx.emit(Inst{ .str = .{
                    .src = value_reg,
                    .base = fp_reg,
                    .offset = fp_offset,
                    .size = size,
                } });

                _ = slot_data; // TODO: Use slot_data for size/alignment checks
                return true;
            }
        },
        .ternary => |data| {
            if (data.opcode == .select) {
                // Conditional select: dst = (cond != 0) ? true_val : false_val
                const cond = data.args[0];
                const true_val = data.args[1];
                const false_val = data.args[2];

                // Get registers for operands
                const cond_reg = Reg.fromVReg(try ctx.getValueReg(cond, .int));
                const true_reg = Reg.fromVReg(try ctx.getValueReg(true_val, .int));
                const false_reg = Reg.fromVReg(try ctx.getValueReg(false_val, .int));

                // Allocate output register
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                // Determine operand size from result type
                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Test condition against zero
                try ctx.emit(Inst{ .cmp_imm = .{
                    .src = cond_reg,
                    .imm = 0,
                    .size = size,
                } });

                // Conditional select: if condition != 0, use true_val, else false_val
                try ctx.emit(Inst{
                    .csel = .{
                        .dst = dst,
                        .src1 = true_reg,
                        .src2 = false_reg,
                        .cond = .ne, // non-equal (condition != 0)
                        .size = size,
                    },
                });

                return true;
            } else if (data.opcode == .bitselect) {
                // Bitwise select: dst = (a & c) | (b & ~c)
                // Where c is the selector, a is chosen for set bits, b for clear bits
                const a = data.args[0];
                const b = data.args[1];
                const c = data.args[2];

                const a_reg = Reg.fromVReg(try ctx.getValueReg(a, .int));
                const b_reg = Reg.fromVReg(try ctx.getValueReg(b, .int));
                const c_reg = Reg.fromVReg(try ctx.getValueReg(c, .int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Emit (a & c) | (b & ~c) sequence
                // tmp1 = a & c
                const tmp1 = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{ .and_rr = .{
                    .dst = tmp1,
                    .src1 = a_reg,
                    .src2 = c_reg,
                    .size = size,
                } });

                // tmp2 = b & ~c (using bic: b & NOT c)
                const tmp2 = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{ .bic_rr = .{
                    .dst = tmp2,
                    .src1 = b_reg,
                    .src2 = c_reg,
                    .size = size,
                } });

                // dst = tmp1 | tmp2
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));
                try ctx.emit(Inst{ .orr_rr = .{
                    .dst = dst,
                    .src1 = tmp1.toReg(),
                    .src2 = tmp2.toReg(),
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .fma) {
                // Fused multiply-add: dst = args[2] + (args[0] * args[1])
                const src1 = data.args[0];
                const src2 = data.args[1];
                const addend = data.args[2];

                const src1_reg = Reg.fromVReg(try ctx.getValueReg(src1, .float));
                const src2_reg = Reg.fromVReg(try ctx.getValueReg(src2, .float));
                const addend_reg = Reg.fromVReg(try ctx.getValueReg(addend, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.float));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                try ctx.emit(Inst{ .fmadd = .{
                    .dst = dst,
                    .src1 = src1_reg,
                    .src2 = src2_reg,
                    .addend = addend_reg,
                    .size = size,
                } });
                return true;
            }
        },
        .float_compare => |data| {
            if (data.opcode == .fcmp) {
                // Float comparison: compare two float registers
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .float));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .float));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(ctx.func.dfg.firstResult(ir_inst) orelse return false);
                const size: FpuOperandSize = if (ty.bits() == 32) .size32 else .size64;

                // Map FloatCC to ARM64 CondCode
                // ARM64 FCMP sets NZCV flags that we test with conditional codes
                const cond: CondCode = switch (data.cond) {
                    .eq => .eq, // equal
                    .ne => .ne, // not equal (handles unordered)
                    .lt => .mi, // less than (N set, no unordered)
                    .le => .ls, // less or equal (C clear or Z set)
                    .gt => .gt, // greater than
                    .ge => .ge, // greater or equal
                    .uno => .vs, // unordered (V set - at least one NaN)
                    .ord => .vc, // ordered (V clear - neither is NaN)
                    .ueq => .eq, // unordered or equal
                    .one => .mi, // ordered not equal (use mi for now, complex)
                    .ult => .lt, // unordered or less
                    .ule => .le, // unordered or less/equal
                    .ugt => .hi, // unordered or greater
                    .uge => .cs, // unordered or greater/equal
                };

                // Emit fcmp instruction
                try ctx.emit(Inst{ .fcmp = .{
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
                    .size = size,
                } });

                // Emit cset instruction to materialize result in register
                try ctx.emit(Inst{ .cset = .{
                    .dst = dst,
                    .cond = cond,
                    .size = .size64,
                } });

                return true;
            }
        },
        else => {},
    }

    // Return false to indicate instruction not handled
    return false;
}
