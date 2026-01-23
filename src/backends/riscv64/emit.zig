const std = @import("std");
const testing = std.testing;

const inst_mod = @import("inst.zig");
const Inst = inst_mod.Inst;
const Reg = inst_mod.Reg;
const PReg = inst_mod.PReg;
const CallTarget = inst_mod.CallTarget;
const RoundingMode = inst_mod.RoundingMode;
const buffer_mod = @import("../../machinst/buffer.zig");

pub fn emit(inst: Inst, buffer: *buffer_mod.MachBuffer) !void {
    switch (inst) {
        .add => |i| try emitR(0b0110011, i.dst.toReg(), 0b000, i.src1, i.src2, 0b0000000, buffer),
        .addi => |i| try emitI(0b0010011, i.dst.toReg(), 0b000, i.src, i.imm, buffer),
        .addw => |i| try emitR(0b0111011, i.dst.toReg(), 0b000, i.src1, i.src2, 0b0000000, buffer),
        .addiw => |i| try emitI(0b0011011, i.dst.toReg(), 0b000, i.src, i.imm, buffer),
        .sub => |i| try emitR(0b0110011, i.dst.toReg(), 0b000, i.src1, i.src2, 0b0100000, buffer),
        .subw => |i| try emitR(0b0111011, i.dst.toReg(), 0b000, i.src1, i.src2, 0b0100000, buffer),
        .sll => |i| try emitR(0b0110011, i.dst.toReg(), 0b001, i.src1, i.src2, 0b0000000, buffer),
        .slli => |i| try emitIShift64(0b0010011, i.dst.toReg(), 0b001, i.src, i.shamt, 0b000000, buffer),
        .sllw => |i| try emitR(0b0111011, i.dst.toReg(), 0b001, i.src1, i.src2, 0b0000000, buffer),
        .slliw => |i| try emitIShift32(0b0011011, i.dst.toReg(), 0b001, i.src, i.shamt, 0b0000000, buffer),
        .srl => |i| try emitR(0b0110011, i.dst.toReg(), 0b101, i.src1, i.src2, 0b0000000, buffer),
        .srli => |i| try emitIShift64(0b0010011, i.dst.toReg(), 0b101, i.src, i.shamt, 0b000000, buffer),
        .srlw => |i| try emitR(0b0111011, i.dst.toReg(), 0b101, i.src1, i.src2, 0b0000000, buffer),
        .srliw => |i| try emitIShift32(0b0011011, i.dst.toReg(), 0b101, i.src, i.shamt, 0b0000000, buffer),
        .sra => |i| try emitR(0b0110011, i.dst.toReg(), 0b101, i.src1, i.src2, 0b0100000, buffer),
        .srai => |i| try emitIShift64(0b0010011, i.dst.toReg(), 0b101, i.src, i.shamt, 0b010000, buffer),
        .sraw => |i| try emitR(0b0111011, i.dst.toReg(), 0b101, i.src1, i.src2, 0b0100000, buffer),
        .sraiw => |i| try emitIShift32(0b0011011, i.dst.toReg(), 0b101, i.src, i.shamt, 0b0100000, buffer),
        .@"and" => |i| try emitR(0b0110011, i.dst.toReg(), 0b111, i.src1, i.src2, 0b0000000, buffer),
        .andi => |i| try emitI(0b0010011, i.dst.toReg(), 0b111, i.src, i.imm, buffer),
        .@"or" => |i| try emitR(0b0110011, i.dst.toReg(), 0b110, i.src1, i.src2, 0b0000000, buffer),
        .ori => |i| try emitI(0b0010011, i.dst.toReg(), 0b110, i.src, i.imm, buffer),
        .xor => |i| try emitR(0b0110011, i.dst.toReg(), 0b100, i.src1, i.src2, 0b0000000, buffer),
        .xori => |i| try emitI(0b0010011, i.dst.toReg(), 0b100, i.src, i.imm, buffer),
        .slt => |i| try emitR(0b0110011, i.dst.toReg(), 0b010, i.src1, i.src2, 0b0000000, buffer),
        .slti => |i| try emitI(0b0010011, i.dst.toReg(), 0b010, i.src, i.imm, buffer),
        .sltu => |i| try emitR(0b0110011, i.dst.toReg(), 0b011, i.src1, i.src2, 0b0000000, buffer),
        .sltiu => |i| try emitI(0b0010011, i.dst.toReg(), 0b011, i.src, i.imm, buffer),
        .lui => |i| try emitU(0b0110111, i.dst.toReg(), i.imm, buffer),
        .auipc => |i| try emitU(0b0010111, i.dst.toReg(), i.imm, buffer),

        // Loads
        .lb => |i| try emitI(0b0000011, i.dst.toReg(), 0b000, i.base, i.offset, buffer),
        .lh => |i| try emitI(0b0000011, i.dst.toReg(), 0b001, i.base, i.offset, buffer),
        .lw => |i| try emitI(0b0000011, i.dst.toReg(), 0b010, i.base, i.offset, buffer),
        .ld => |i| try emitI(0b0000011, i.dst.toReg(), 0b011, i.base, i.offset, buffer),
        .lbu => |i| try emitI(0b0000011, i.dst.toReg(), 0b100, i.base, i.offset, buffer),
        .lhu => |i| try emitI(0b0000011, i.dst.toReg(), 0b101, i.base, i.offset, buffer),
        .lwu => |i| try emitI(0b0000011, i.dst.toReg(), 0b110, i.base, i.offset, buffer),

        // Stores
        .sb => |i| try emitS(0b0100011, 0b000, i.base, i.src, i.offset, buffer),
        .sh => |i| try emitS(0b0100011, 0b001, i.base, i.src, i.offset, buffer),
        .sw => |i| try emitS(0b0100011, 0b010, i.base, i.src, i.offset, buffer),
        .sd => |i| try emitS(0b0100011, 0b011, i.base, i.src, i.offset, buffer),

        // Branches
        .beq => |i| try emitB(0b1100011, 0b000, i.src1, i.src2, i.offset, buffer),
        .bne => |i| try emitB(0b1100011, 0b001, i.src1, i.src2, i.offset, buffer),
        .blt => |i| try emitB(0b1100011, 0b100, i.src1, i.src2, i.offset, buffer),
        .bge => |i| try emitB(0b1100011, 0b101, i.src1, i.src2, i.offset, buffer),
        .bltu => |i| try emitB(0b1100011, 0b110, i.src1, i.src2, i.offset, buffer),
        .bgeu => |i| try emitB(0b1100011, 0b111, i.src1, i.src2, i.offset, buffer),

        // Jumps
        .jal => |i| try emitJ(0b1101111, i.dst.toReg(), i.offset, buffer),
        .jalr => |i| try emitI(0b1100111, i.dst.toReg(), 0b000, i.base, i.offset, buffer),

        // M Extension
        .mul => |i| try emitR(0b0110011, i.dst.toReg(), 0b000, i.src1, i.src2, 0b0000001, buffer),
        .mulh => |i| try emitR(0b0110011, i.dst.toReg(), 0b001, i.src1, i.src2, 0b0000001, buffer),
        .mulhsu => |i| try emitR(0b0110011, i.dst.toReg(), 0b010, i.src1, i.src2, 0b0000001, buffer),
        .mulhu => |i| try emitR(0b0110011, i.dst.toReg(), 0b011, i.src1, i.src2, 0b0000001, buffer),
        .mulw => |i| try emitR(0b0111011, i.dst.toReg(), 0b000, i.src1, i.src2, 0b0000001, buffer),
        .div => |i| try emitR(0b0110011, i.dst.toReg(), 0b100, i.src1, i.src2, 0b0000001, buffer),
        .divu => |i| try emitR(0b0110011, i.dst.toReg(), 0b101, i.src1, i.src2, 0b0000001, buffer),
        .rem => |i| try emitR(0b0110011, i.dst.toReg(), 0b110, i.src1, i.src2, 0b0000001, buffer),
        .remu => |i| try emitR(0b0110011, i.dst.toReg(), 0b111, i.src1, i.src2, 0b0000001, buffer),
        .divw => |i| try emitR(0b0111011, i.dst.toReg(), 0b100, i.src1, i.src2, 0b0000001, buffer),
        .divuw => |i| try emitR(0b0111011, i.dst.toReg(), 0b101, i.src1, i.src2, 0b0000001, buffer),
        .remw => |i| try emitR(0b0111011, i.dst.toReg(), 0b110, i.src1, i.src2, 0b0000001, buffer),
        .remuw => |i| try emitR(0b0111011, i.dst.toReg(), 0b111, i.src1, i.src2, 0b0000001, buffer),

        // F/D Extensions
        .flw => |i| try emitI(0b0000111, i.dst.toReg(), 0b010, i.base, i.offset, buffer),
        .fld => |i| try emitI(0b0000111, i.dst.toReg(), 0b011, i.base, i.offset, buffer),
        .fsw => |i| try emitS(0b0100111, 0b010, i.base, i.src, i.offset, buffer),
        .fsd => |i| try emitS(0b0100111, 0b011, i.base, i.src, i.offset, buffer),

        .fadd_s => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src1, i.src2, 0b00000, buffer),
        .fadd_d => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src1, i.src2, 0b00001, buffer),
        .fsub_s => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src1, i.src2, 0b00100, buffer),
        .fsub_d => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src1, i.src2, 0b00101, buffer),
        .fmul_s => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src1, i.src2, 0b01000, buffer),
        .fmul_d => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src1, i.src2, 0b01001, buffer),
        .fdiv_s => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src1, i.src2, 0b01100, buffer),
        .fdiv_d => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src1, i.src2, 0b01101, buffer),

        .fsqrt_s => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, zeroReg(), 0b01011, buffer),
        .fsqrt_d => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, zeroReg(), 0b01011 | 0b1, buffer),

        .fmin_s => |i| try emitR4(0b1010011, i.dst.toReg(), 0b000, i.src1, i.src2, 0b00101, buffer),
        .fmin_d => |i| try emitR4(0b1010011, i.dst.toReg(), 0b000, i.src1, i.src2, 0b00101 | 0b1, buffer),
        .fmax_s => |i| try emitR4(0b1010011, i.dst.toReg(), 0b001, i.src1, i.src2, 0b00101, buffer),
        .fmax_d => |i| try emitR4(0b1010011, i.dst.toReg(), 0b001, i.src1, i.src2, 0b00101 | 0b1, buffer),

        .feq_s => |i| try emitR4(0b1010011, i.dst.toReg(), 0b010, i.src1, i.src2, 0b10100, buffer),
        .feq_d => |i| try emitR4(0b1010011, i.dst.toReg(), 0b010, i.src1, i.src2, 0b10101, buffer),
        .flt_s => |i| try emitR4(0b1010011, i.dst.toReg(), 0b001, i.src1, i.src2, 0b10100, buffer),
        .flt_d => |i| try emitR4(0b1010011, i.dst.toReg(), 0b001, i.src1, i.src2, 0b10101, buffer),
        .fle_s => |i| try emitR4(0b1010011, i.dst.toReg(), 0b000, i.src1, i.src2, 0b10100, buffer),
        .fle_d => |i| try emitR4(0b1010011, i.dst.toReg(), 0b000, i.src1, i.src2, 0b10101, buffer),

        .fmv_x_w => |i| try emitR4(0b1010011, i.dst.toReg(), 0b000, i.src, zeroReg(), 0b11100, buffer),
        .fmv_x_d => |i| try emitR4(0b1010011, i.dst.toReg(), 0b000, i.src, zeroReg(), 0b11101, buffer),
        .fmv_w_x => |i| try emitR4(0b1010011, i.dst.toReg(), 0b000, i.src, zeroReg(), 0b11110, buffer),
        .fmv_d_x => |i| try emitR4(0b1010011, i.dst.toReg(), 0b000, i.src, zeroReg(), 0b11111, buffer),

        .fcvt_w_s => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, zeroReg(), 0b11000, buffer),
        .fcvt_w_d => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, zeroReg(), 0b11001, buffer),
        .fcvt_wu_s => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(1), 0b11000, buffer),
        .fcvt_wu_d => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(1), 0b11001, buffer),
        .fcvt_l_s => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(2), 0b11000, buffer),
        .fcvt_l_d => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(2), 0b11001, buffer),
        .fcvt_lu_s => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(3), 0b11000, buffer),
        .fcvt_lu_d => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(3), 0b11001, buffer),

        .fcvt_s_w => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, zeroReg(), 0b11010, buffer),
        .fcvt_d_w => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, zeroReg(), 0b11011, buffer),
        .fcvt_s_wu => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(1), 0b11010, buffer),
        .fcvt_d_wu => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(1), 0b11011, buffer),
        .fcvt_s_l => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(2), 0b11010, buffer),
        .fcvt_d_l => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(2), 0b11011, buffer),
        .fcvt_s_lu => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(3), 0b11010, buffer),
        .fcvt_d_lu => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(3), 0b11011, buffer),

        .fcvt_d_s => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, zeroReg(), 0b01000 | 0b1, buffer),
        .fcvt_s_d => |i| try emitR4(0b1010011, i.dst.toReg(), @intFromEnum(i.rm), i.src, regAtEnc(1), 0b01000, buffer),

        // System
        .fence => |i| try emitFence(i.pred, i.succ, buffer),
        .fence_i => try emitI(0b0001111, zeroReg(), 0b001, zeroReg(), 0, buffer),
        .ecall => try emitI(0b1110011, zeroReg(), 0b000, zeroReg(), 0, buffer),
        .ebreak => try emitI(0b1110011, zeroReg(), 0b000, zeroReg(), 1, buffer),
        .udf => try buffer.putData(&[_]u8{0, 0, 0, 0}),

        // A Extension
        .lr_w => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b010, i.addr, zeroReg(), aqrlBits(i.aq, i.rl), 0b00010, buffer),
        .sc_w => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b010, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b00011, buffer),
        .lr_d => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b011, i.addr, zeroReg(), aqrlBits(i.aq, i.rl), 0b00010, buffer),
        .sc_d => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b011, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b00011, buffer),
        .amoswap_w => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b010, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b00001, buffer),
        .amoadd_w => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b010, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b00000, buffer),
        .amoxor_w => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b010, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b00100, buffer),
        .amoand_w => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b010, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b01100, buffer),
        .amoor_w => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b010, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b01000, buffer),
        .amomin_w => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b010, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b10000, buffer),
        .amomax_w => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b010, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b10100, buffer),
        .amominu_w => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b010, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b11000, buffer),
        .amomaxu_w => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b010, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b11100, buffer),
        .amoswap_d => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b011, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b00001, buffer),
        .amoadd_d => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b011, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b00000, buffer),
        .amoxor_d => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b011, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b00100, buffer),
        .amoand_d => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b011, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b01100, buffer),
        .amoor_d => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b011, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b01000, buffer),
        .amomin_d => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b011, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b10000, buffer),
        .amomax_d => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b011, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b10100, buffer),
        .amominu_d => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b011, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b11000, buffer),
        .amomaxu_d => |i| try emitAtomic(0b0101111, i.dst.toReg(), 0b011, i.addr, i.src, aqrlBits(i.aq, i.rl), 0b11100, buffer),

        // Pseudo-instructions
        .mv => |i| try emitI(0b0010011, i.dst.toReg(), 0b000, i.src, 0, buffer),
        .li => |i| try emitLoadImm(i.dst.toReg(), i.imm, buffer),
        .ret => try emitI(0b1100111, zeroReg(), 0b000, raReg(), 0, buffer),
        .call => |i| switch (i.target) {
            .direct => |off| try emitCall(off, buffer),
            .indirect => |reg| try emitI(0b1100111, raReg(), 0b000, reg, 0, buffer),
        },
        .nop => try emitI(0b0010011, zeroReg(), 0b000, zeroReg(), 0, buffer),
    }
}

// R-type: opcode[6:0] | rd[11:7] | funct3[14:12] | rs1[19:15] | rs2[24:20] | funct7[31:25]
fn emitR(opcode: u7, rd: Reg, funct3: u3, rs1: Reg, rs2: Reg, funct7: u7, buffer: *buffer_mod.MachBuffer) !void {
    const rd_enc = hwEnc(rd);
    const rs1_enc = hwEnc(rs1);
    const rs2_enc = hwEnc(rs2);

    const word: u32 = @as(u32, opcode) |
        (@as(u32, rd_enc) << 7) |
        (@as(u32, funct3) << 12) |
        (@as(u32, rs1_enc) << 15) |
        (@as(u32, rs2_enc) << 20) |
        (@as(u32, funct7) << 25);

    try buffer.putData(&std.mem.toBytes(word));
}

// I-type: opcode[6:0] | rd[11:7] | funct3[14:12] | rs1[19:15] | imm[31:20]
fn emitI(opcode: u7, rd: Reg, funct3: u3, rs1: Reg, imm: i12, buffer: *buffer_mod.MachBuffer) !void {
    const rd_enc = hwEnc(rd);
    const rs1_enc = hwEnc(rs1);
    const imm_u: u12 = @bitCast(imm);

    const word: u32 = @as(u32, opcode) |
        (@as(u32, rd_enc) << 7) |
        (@as(u32, funct3) << 12) |
        (@as(u32, rs1_enc) << 15) |
        (@as(u32, imm_u) << 20);

    try buffer.putData(&std.mem.toBytes(word));
}

// I-type shift (64-bit): shamt[5:0]
fn emitIShift64(opcode: u7, rd: Reg, funct3: u3, rs1: Reg, shamt: u6, funct6: u6, buffer: *buffer_mod.MachBuffer) !void {
    const rd_enc = hwEnc(rd);
    const rs1_enc = hwEnc(rs1);

    const word: u32 = @as(u32, opcode) |
        (@as(u32, rd_enc) << 7) |
        (@as(u32, funct3) << 12) |
        (@as(u32, rs1_enc) << 15) |
        (@as(u32, shamt) << 20) |
        (@as(u32, funct6) << 26);

    try buffer.putData(&std.mem.toBytes(word));
}

// I-type shift (32-bit): shamt[4:0]
fn emitIShift32(opcode: u7, rd: Reg, funct3: u3, rs1: Reg, shamt: u5, funct7: u7, buffer: *buffer_mod.MachBuffer) !void {
    const rd_enc = hwEnc(rd);
    const rs1_enc = hwEnc(rs1);

    const word: u32 = @as(u32, opcode) |
        (@as(u32, rd_enc) << 7) |
        (@as(u32, funct3) << 12) |
        (@as(u32, rs1_enc) << 15) |
        (@as(u32, shamt) << 20) |
        (@as(u32, funct7) << 25);

    try buffer.putData(&std.mem.toBytes(word));
}

// S-type: opcode[6:0] | imm[4:0][11:7] | funct3[14:12] | rs1[19:15] | rs2[24:20] | imm[11:5][31:25]
fn emitS(opcode: u7, funct3: u3, rs1: Reg, rs2: Reg, imm: i12, buffer: *buffer_mod.MachBuffer) !void {
    const rs1_enc = hwEnc(rs1);
    const rs2_enc = hwEnc(rs2);
    const imm_u: u12 = @bitCast(imm);
    const imm_low: u5 = @truncate(imm_u);
    const imm_high: u7 = @truncate(imm_u >> 5);

    const word: u32 = @as(u32, opcode) |
        (@as(u32, imm_low) << 7) |
        (@as(u32, funct3) << 12) |
        (@as(u32, rs1_enc) << 15) |
        (@as(u32, rs2_enc) << 20) |
        (@as(u32, imm_high) << 25);

    try buffer.putData(&std.mem.toBytes(word));
}

// B-type: branch offset encoding
fn emitB(opcode: u7, funct3: u3, rs1: Reg, rs2: Reg, offset: i13, buffer: *buffer_mod.MachBuffer) !void {
    const rs1_enc = hwEnc(rs1);
    const rs2_enc = hwEnc(rs2);
    const off_u: u13 = @bitCast(offset);

    // B-type encoding: imm[12|10:5][4:1|11]
    const imm_11: u1 = @truncate(off_u >> 11);
    const imm_4_1: u4 = @truncate(off_u >> 1);
    const imm_10_5: u6 = @truncate(off_u >> 5);
    const imm_12: u1 = @truncate(off_u >> 12);

    const word: u32 = @as(u32, opcode) |
        (@as(u32, imm_11) << 7) |
        (@as(u32, imm_4_1) << 8) |
        (@as(u32, funct3) << 12) |
        (@as(u32, rs1_enc) << 15) |
        (@as(u32, rs2_enc) << 20) |
        (@as(u32, imm_10_5) << 25) |
        (@as(u32, imm_12) << 31);

    try buffer.putData(&std.mem.toBytes(word));
}

// U-type: opcode[6:0] | rd[11:7] | imm[31:12]
fn emitU(opcode: u7, rd: Reg, imm: i32, buffer: *buffer_mod.MachBuffer) !void {
    const rd_enc = hwEnc(rd);
    const imm_u: u32 = @bitCast(imm);
    const imm20: u20 = @truncate(imm_u >> 12);

    const word: u32 = @as(u32, opcode) |
        (@as(u32, rd_enc) << 7) |
        (@as(u32, imm20) << 12);

    try buffer.putData(&std.mem.toBytes(word));
}

// J-type: jal offset encoding
fn emitJ(opcode: u7, rd: Reg, offset: i21, buffer: *buffer_mod.MachBuffer) !void {
    const rd_enc = hwEnc(rd);
    const off_u: u21 = @bitCast(offset);

    // J-type encoding: imm[20|10:1|11|19:12]
    const imm_19_12: u8 = @truncate(off_u >> 12);
    const imm_11: u1 = @truncate(off_u >> 11);
    const imm_10_1: u10 = @truncate(off_u >> 1);
    const imm_20: u1 = @truncate(off_u >> 20);

    const word: u32 = @as(u32, opcode) |
        (@as(u32, rd_enc) << 7) |
        (@as(u32, imm_19_12) << 12) |
        (@as(u32, imm_11) << 20) |
        (@as(u32, imm_10_1) << 21) |
        (@as(u32, imm_20) << 31);

    try buffer.putData(&std.mem.toBytes(word));
}

// R4-type (FP): opcode | rd | rm | rs1 | rs2 | funct5
fn emitR4(opcode: u7, rd: Reg, rm: u3, rs1: Reg, rs2: Reg, funct7: u7, buffer: *buffer_mod.MachBuffer) !void {
    const rd_enc = hwEnc(rd);
    const rs1_enc = hwEnc(rs1);
    const rs2_enc = hwEnc(rs2);

    const word: u32 = @as(u32, opcode) |
        (@as(u32, rd_enc) << 7) |
        (@as(u32, rm) << 12) |
        (@as(u32, rs1_enc) << 15) |
        (@as(u32, rs2_enc) << 20) |
        (@as(u32, funct7) << 25);

    try buffer.putData(&std.mem.toBytes(word));
}

// Atomic R-type
fn emitAtomic(opcode: u7, rd: Reg, funct3: u3, rs1: Reg, rs2: Reg, aqrl: u2, funct5: u5, buffer: *buffer_mod.MachBuffer) !void {
    const rd_enc = hwEnc(rd);
    const rs1_enc = hwEnc(rs1);
    const rs2_enc = hwEnc(rs2);

    const word: u32 = @as(u32, opcode) |
        (@as(u32, rd_enc) << 7) |
        (@as(u32, funct3) << 12) |
        (@as(u32, rs1_enc) << 15) |
        (@as(u32, rs2_enc) << 20) |
        (@as(u32, aqrl) << 25) |
        (@as(u32, funct5) << 27);

    try buffer.putData(&std.mem.toBytes(word));
}

fn emitFence(pred: u4, succ: u4, buffer: *buffer_mod.MachBuffer) !void {
    const word: u32 = 0b0001111 |
        (@as(u32, succ) << 20) |
        (@as(u32, pred) << 24);

    try buffer.putData(&std.mem.toBytes(word));
}

fn emitLoadImm(rd: Reg, imm: i64, buffer: *buffer_mod.MachBuffer) !void {
    // Load 64-bit immediate via lui + addi sequence
    const low: i32 = @truncate(imm);
    const high: i32 = @truncate(imm >> 32);

    if (high == 0 or high == -1) {
        // Fits in 32 bits
        const upper: i32 = (low + 0x800) >> 12;
        const lower: i12 = @truncate(low);

        if (upper != 0) {
            try emitU(0b0110111, rd, upper << 12, buffer);
            if (lower != 0) {
                try emitI(0b0010011, rd, 0b000, rd, lower, buffer);
            }
        } else {
            try emitI(0b0010011, rd, 0b000, zeroReg(), lower, buffer);
        }
    } else {
        // Need full 64-bit sequence - simplified version
        const upper: i32 = @truncate((low >> 12) & 0xFFFFF);
        const lower_imm: i12 = @truncate(low & 0xFFF);
        try emitU(0b0110111, rd, upper, buffer);
        try emitI(0b0010011, rd, 0b000, rd, lower_imm, buffer);
    }
}

fn emitCall(offset: i32, buffer: *buffer_mod.MachBuffer) !void {
    // Simplified: assume offset fits in jal range
    const off21: i21 = @truncate(offset);
    try emitJ(0b1101111, raReg(), off21, buffer);
}

fn hwEnc(reg: Reg) u5 {
    if (reg.toRealReg()) |rreg| {
        return @truncate(rreg.hwEnc());
    }
    return 0; // Placeholder for vregs
}

fn zeroReg() Reg {
    const regs = @import("regs.zig");
    return regs.zero();
}

fn raReg() Reg {
    const regs = @import("regs.zig");
    return regs.ra();
}

fn regAtEnc(enc: u8) Reg {
    const regs = @import("regs.zig");
    return regs.gpr(enc);
}

fn aqrlBits(aq: bool, rl: bool) u2 {
    return (@as(u2, @intFromBool(aq)) << 1) | @intFromBool(rl);
}

test "R-type encoding" {
    var buf = buffer_mod.MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const regs = @import("regs.zig");
    try emitR(0b0110011, regs.a0(), 0b000, regs.a1(), regs.a2(), 0b0000000, &buf);

    const bytes = buf.data.items;
    try testing.expectEqual(@as(usize, 4), bytes.len);

    // add a0, a1, a2: opcode=0x33, rd=10, funct3=0, rs1=11, rs2=12, funct7=0
    const expected: u32 = 0b0000000_01100_01011_000_01010_0110011;
    const actual = std.mem.readInt(u32, bytes[0..4], .little);
    try testing.expectEqual(expected, actual);
}

test "I-type encoding" {
    var buf = buffer_mod.MachBuffer.init(testing.allocator);
    defer buf.deinit();

    const regs = @import("regs.zig");
    try emitI(0b0010011, regs.a0(), 0b000, regs.a1(), 42, &buf);

    const bytes = buf.data.items;
    try testing.expectEqual(@as(usize, 4), bytes.len);

    // addi a0, a1, 42
    const expected: u32 = 0b000000101010_01011_000_01010_0010011;
    const actual = std.mem.readInt(u32, bytes[0..4], .little);
    try testing.expectEqual(expected, actual);
}
