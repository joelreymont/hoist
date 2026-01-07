// Generated ISLE lowering for aarch64
// TODO: Replace with actual ISLE-generated code when parser is complete

const std = @import("std");
const root = @import("root");
const inst_mod = @import("../backends/aarch64/inst.zig");
const Inst = inst_mod.Inst;
const Reg = inst_mod.Reg;
const WritableReg = inst_mod.WritableReg;
const OperandSize = inst_mod.OperandSize;
const CondCode = inst_mod.CondCode;
const lower_mod = @import("../machinst/lower.zig");

const Opcode = root.opcodes.Opcode;
const InstructionData = root.instruction_data.InstructionData;
const Type = root.types.Type;
const IntCC = root.condcodes.IntCC;

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
            } else if (data.opcode == .uload8) {
                // Load unsigned byte (zero-extend)
                const addr = data.arg;
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                // Result type determines destination size
                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .ldrb = .{
                    .dst = dst,
                    .base = addr_reg,
                    .offset = @intCast(data.offset.value),
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .sload8) {
                // Load signed byte (sign-extend)
                const addr = data.arg;
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .ldrsb = .{
                    .dst = dst,
                    .base = addr_reg,
                    .offset = @intCast(data.offset.value),
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .uload16) {
                // Load unsigned halfword (zero-extend)
                const addr = data.arg;
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .ldrh = .{
                    .dst = dst,
                    .base = addr_reg,
                    .offset = @intCast(data.offset.value),
                    .size = size,
                } });

                return true;
            } else if (data.opcode == .sload16) {
                // Load signed halfword (sign-extend)
                const addr = data.arg;
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
                const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;

                try ctx.emit(Inst{ .ldrsh = .{
                    .dst = dst,
                    .base = addr_reg,
                    .offset = @intCast(data.offset.value),
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
                    .offset = @intCast(data.offset.value),
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
                    .offset = @intCast(data.offset.value),
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
            } else if (data.opcode == .istore8) {
                // Store byte
                const value = data.arg;
                const addr = data.addr;

                const value_reg = Reg.fromVReg(try ctx.getValueReg(value, .int));
                const addr_reg = Reg.fromVReg(try ctx.getValueReg(addr, .int));

                try ctx.emit(Inst{ .strb = .{
                    .src = value_reg,
                    .base = addr_reg,
                    .offset = @intCast(data.offset.value),
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
                    .offset = @intCast(data.offset.value),
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
                    .offset = @intCast(data.offset.value),
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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
                const dst_ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));

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
                const dst_ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));

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

                const dst_ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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
        .int_compare => |data| {
            if (data.opcode == .icmp) {
                // Integer comparison: compare two registers
                const lhs = data.args[0];
                const rhs = data.args[1];

                const lhs_reg = Reg.fromVReg(try ctx.getValueReg(lhs, .int));
                const rhs_reg = Reg.fromVReg(try ctx.getValueReg(rhs, .int));
                const dst = WritableReg.fromVReg(ctx.allocVReg(.int));

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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
                            try ctx.emit(Inst{ .neg_rr = .{
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
                            try ctx.emit(Inst{ .neg_rr = .{
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

                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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
                const ty = ctx.getValueType(root.entities.Value.fromInst(ir_inst));
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
            }
        },
        else => {},
    }

    // Return false to indicate instruction not handled
    return false;
}
