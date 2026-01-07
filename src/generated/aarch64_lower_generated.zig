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
                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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
                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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
                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .asr_rr = .{
                    .dst = dst,
                    .src1 = lhs_reg,
                    .src2 = rhs_reg,
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
                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                // Emit load instruction with offset from LoadData
                try ctx.emit(Inst{ .ldr = .{
                    .dst = dst,
                    .base = addr_reg,
                    .offset = @intCast(data.offset.value),
                    .size = size,
                } });

                return true;
            }
        },
        .store => |data| {
            if (data.opcode == .store) {
                // Get value and address operands
                const value = data.arg;
                const addr = data.addr;

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
                    .offset = @intCast(data.offset.value),
                    .size = size,
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .mvn_rr = .{
                    .dst = dst,
                    .src = src_reg,
                    .size = size,
                } });

                return true;
            }
        },
        .nullary => |data| {
            if (data.opcode == .@"return") {
                // Void return - just emit ret instruction
                try ctx.emit(Inst.ret);
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
        else => {},
    }

    // Return false to indicate instruction not handled
    return false;
}
