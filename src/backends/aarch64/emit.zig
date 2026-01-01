const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const OperandSize = root.aarch64_inst.OperandSize;
const Reg = root.aarch64_inst.Reg;
const PReg = root.aarch64_inst.PReg;
const buffer_mod = root.buffer;

/// Emit aarch64 instruction to binary.
/// This is a minimal bootstrap - full aarch64 emission needs:
/// - Complete instruction encoding with all formats
/// - Shifted/extended operand support
/// - Wide immediate materialization
/// - Vector instructions
pub fn emit(inst: Inst, buffer: *buffer_mod.MachBuffer) !void {
    switch (inst) {
        .mov_rr => |i| try emitMovRR(i.dst.toReg(), i.src, i.size, buffer),
        .mov_imm => |i| try emitMovImm(i.dst.toReg(), i.imm, i.size, buffer),
        .movz => |i| try emitMovz(i.dst.toReg(), i.imm, i.shift, i.size, buffer),
        .movk => |i| try emitMovk(i.dst.toReg(), i.imm, i.shift, i.size, buffer),
        .movn => |i| try emitMovn(i.dst.toReg(), i.imm, i.shift, i.size, buffer),
        .add_rr => |i| try emitAddRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .add_imm => |i| try emitAddImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .sub_rr => |i| try emitSubRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .sub_imm => |i| try emitSubImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .mul_rr => |i| try emitMulRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .madd => |i| try emitMadd(i.dst.toReg(), i.src1, i.src2, i.addend, i.size, buffer),
        .msub => |i| try emitMsub(i.dst.toReg(), i.src1, i.src2, i.subtrahend, i.size, buffer),
        .smulh => |i| try emitSmulh(i.dst.toReg(), i.src1, i.src2, buffer),
        .umulh => |i| try emitUmulh(i.dst.toReg(), i.src1, i.src2, buffer),
        .smull => |i| try emitSmull(i.dst.toReg(), i.src1, i.src2, buffer),
        .umull => |i| try emitUmull(i.dst.toReg(), i.src1, i.src2, buffer),
        .sdiv => |i| try emitSdiv(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .udiv => |i| try emitUdiv(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .lsl_rr => |i| try emitLslRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .lsl_imm => |i| try emitLslImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .lsr_rr => |i| try emitLsrRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .lsr_imm => |i| try emitLsrImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .asr_rr => |i| try emitAsrRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .asr_imm => |i| try emitAsrImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .ror_rr => |i| try emitRorRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .ror_imm => |i| try emitRorImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .and_rr => |i| try emitAndRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .and_imm => |i| try emitAndImm(i.dst.toReg(), i.src, i.imm, buffer),
        .orr_rr => |i| try emitOrrRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .orr_imm => |i| try emitOrrImm(i.dst.toReg(), i.src, i.imm, buffer),
        .eor_rr => |i| try emitEorRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .eor_imm => |i| try emitEorImm(i.dst.toReg(), i.src, i.imm, buffer),
        .mvn_rr => |i| try emitMvnRR(i.dst.toReg(), i.src, i.size, buffer),
        .adds_rr => |i| try emitAddsRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .adds_imm => |i| try emitAddsImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .subs_rr => |i| try emitSubsRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .subs_imm => |i| try emitSubsImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .cmp_rr => |i| try emitCmpRR(i.src1, i.src2, i.size, buffer),
        .cmp_imm => |i| try emitCmpImm(i.src, i.imm, i.size, buffer),
        .cmn_rr => |i| try emitCmnRR(i.src1, i.src2, i.size, buffer),
        .cmn_imm => |i| try emitCmnImm(i.src, i.imm, i.size, buffer),
        .tst_rr => |i| try emitTstRR(i.src1, i.src2, i.size, buffer),
        .tst_imm => |i| try emitTstImm(i.src, i.imm, buffer),
        .clz => |i| try emitClz(i.dst.toReg(), i.src, i.size, buffer),
        .cls => |i| try emitCls(i.dst.toReg(), i.src, i.size, buffer),
        .rbit => |i| try emitRbit(i.dst.toReg(), i.src, i.size, buffer),
        .ldr => |i| try emitLdr(i.dst.toReg(), i.base, i.offset, i.size, buffer),
        .ldr_reg => |i| try emitLdrReg(i.dst.toReg(), i.base, i.offset, i.size, buffer),
        .ldr_ext => |i| try emitLdrExt(i.dst.toReg(), i.base, i.offset, i.extend, i.size, buffer),
        .ldr_scaled => |i| try emitLdrScaled(i.dst.toReg(), i.base, i.offset, i.shift, i.size, buffer),
        .str => |i| try emitStr(i.src, i.base, i.offset, i.size, buffer),
        .str_reg => |i| try emitStrReg(i.src, i.base, i.offset, i.size, buffer),
        .str_ext => |i| try emitStrExt(i.src, i.base, i.offset, i.extend, i.size, buffer),
        .str_scaled => |i| try emitStrScaled(i.src, i.base, i.offset, i.shift, i.size, buffer),
        .stp => |i| try emitStp(i.src1, i.src2, i.base, i.offset, i.size, buffer),
        .ldp => |i| try emitLdp(i.dst1.toReg(), i.dst2.toReg(), i.base, i.offset, i.size, buffer),
        .b => |i| try emitB(i.target.label, buffer),
        .b_cond => |i| try emitBCond(@intFromEnum(i.cond), i.target.label, buffer),
        .bl => |i| switch (i.target) {
            .direct => |_| @panic("External function calls not yet implemented"),
            .indirect => |reg| try emitBLR(reg, buffer),
        },
        .br => |i| try emitBR(i.target, buffer),
        .blr => |i| try emitBLR(i.target, buffer),
        .ret => |i| try emitRet(i.reg, buffer),
        .nop => try emitNop(buffer),
    }
}

/// Get hardware register encoding.
fn hwEnc(reg: Reg) u5 {
    if (reg.isVirtual()) {
        // For testing - map virtual regs to physical
        return @intCast(reg.toVReg().index() % 31);
    } else {
        return @intCast(reg.toPReg().hwEnc() & 0x1F);
    }
}

/// Get sf bit for 64-bit operands.
fn sf(size: OperandSize) u1 {
    return switch (size) {
        .size32 => 0,
        .size64 => 1,
    };
}

/// MOV Xd, Xn (implemented as ORR Xd, XZR, Xn)
fn emitMovRR(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rm = hwEnc(src);

    // ORR Xd, XZR, Xn: sf|01010100|shift|0|Rm|imm6|11111|Rd
    // Using logical shift left by 0
    const insn: u32 = (sf_bit << 31) |
        (0b01010100 << 21) |
        (@as(u32, rm) << 16) |
        (0b11111 << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MOV Xd, #imm (using MOVZ for low 16 bits)
fn emitMovImm(dst: Reg, imm: u64, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const imm16: u16 = @truncate(imm);

    // MOVZ Xd, #imm: sf|10100101|hw|imm16|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b10100101 << 23) |
        (@as(u32, imm16) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MOVZ - Move wide with zero
/// Encoding: sf|opc|100101|hw|imm16|Rd
/// opc=10 for MOVZ, hw = shift / 16
fn emitMovz(dst: Reg, imm: u16, shift: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const hw: u2 = @intCast(shift / 16);

    // MOVZ: sf|10|100101|hw|imm16|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b10100101 << 23) |
        (@as(u32, hw) << 21) |
        (@as(u32, imm) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MOVK - Move wide with keep
/// Encoding: sf|opc|100101|hw|imm16|Rd
/// opc=11 for MOVK, hw = shift / 16
fn emitMovk(dst: Reg, imm: u16, shift: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const hw: u2 = @intCast(shift / 16);

    // MOVK: sf|11|100101|hw|imm16|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11100101 << 23) |
        (@as(u32, hw) << 21) |
        (@as(u32, imm) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MOVN - Move wide with NOT
/// Encoding: sf|opc|100101|hw|imm16|Rd
/// opc=00 for MOVN, hw = shift / 16
fn emitMovn(dst: Reg, imm: u16, shift: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const hw: u2 = @intCast(shift / 16);

    // MOVN: sf|00|100101|hw|imm16|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b00100101 << 23) |
        (@as(u32, hw) << 21) |
        (@as(u32, imm) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ADD Xd, Xn, Xm
fn emitAddRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // ADD: sf|0|0|01011|shift|0|Rm|imm6|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b01011 << 24) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ADD Xd, Xn, #imm
fn emitAddImm(dst: Reg, src: Reg, imm: u16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const imm12: u12 = @truncate(imm);

    // ADD imm: sf|0|0|10001|shift|imm12|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b10001 << 24) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SUB Xd, Xn, Xm
fn emitSubRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // SUB: sf|1|0|01011|shift|0|Rm|imm6|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (1 << 30) |
        (0b01011 << 24) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SUB Xd, Xn, #imm
fn emitSubImm(dst: Reg, src: Reg, imm: u16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const imm12: u12 = @truncate(imm);

    // SUB imm: sf|1|0|10001|shift|imm12|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (1 << 30) |
        (0b10001 << 24) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ADDS Xd, Xn, Xm (add and set flags)
fn emitAddsRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // ADDS: sf|0|1|01011|shift|0|Rm|imm6|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b01 << 29) |
        (0b01011 << 24) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ADDS Xd, Xn, #imm (add immediate and set flags)
fn emitAddsImm(dst: Reg, src: Reg, imm: u16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const imm12: u12 = @truncate(imm);

    // ADDS imm: sf|0|1|10001|shift|imm12|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b01 << 29) |
        (0b10001 << 24) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SUBS Xd, Xn, Xm (subtract and set flags)
fn emitSubsRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // SUBS: sf|1|1|01011|shift|0|Rm|imm6|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11 << 29) |
        (0b01011 << 24) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SUBS Xd, Xn, #imm (subtract immediate and set flags)
fn emitSubsImm(dst: Reg, src: Reg, imm: u16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const imm12: u12 = @truncate(imm);

    // SUBS imm: sf|1|1|10001|shift|imm12|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11 << 29) |
        (0b10001 << 24) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MUL Xd, Xn, Xm (alias for MADD Xd, Xn, Xm, XZR)
fn emitMulRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra: u5 = 31; // XZR

    // MADD: sf|0|0|11011|000|Rm|0|Ra|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11011000 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MADD Xd, Xn, Xm, Xa
fn emitMadd(dst: Reg, src1: Reg, src2: Reg, addend: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra = hwEnc(addend);

    // MADD: sf|0|0|11011|000|Rm|0|Ra|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11011000 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MSUB Xd, Xn, Xm, Xa
fn emitMsub(dst: Reg, src1: Reg, src2: Reg, subtrahend: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra = hwEnc(subtrahend);

    // MSUB: sf|0|0|11011|000|Rm|1|Ra|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11011000 << 21) |
        (@as(u32, rm) << 16) |
        (1 << 15) | // o0 bit
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SMULH Xd, Xn, Xm (signed multiply high)
fn emitSmulh(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra: u5 = 31; // Must be 31

    // SMULH: 1|0|0|11011|010|Rm|0|11111|Rn|Rd
    const insn: u32 = (1 << 31) |
        (0b11011010 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UMULH Xd, Xn, Xm (unsigned multiply high)
fn emitUmulh(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra: u5 = 31; // Must be 31

    // UMULH: 1|0|0|11011|110|Rm|0|11111|Rn|Rd
    const insn: u32 = (1 << 31) |
        (0b11011110 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SMULL Xd, Wn, Wm (signed multiply long 32x32→64)
fn emitSmull(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra: u5 = 31; // XZR

    // SMULL (alias for SMADDL with Ra=31): 1|0|0|11011|001|Rm|0|11111|Rn|Rd
    const insn: u32 = (1 << 31) |
        (0b11011001 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UMULL Xd, Wn, Wm (unsigned multiply long 32x32→64)
fn emitUmull(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra: u5 = 31; // XZR

    // UMULL (alias for UMADDL with Ra=31): 1|0|0|11011|101|Rm|0|11111|Rn|Rd
    const insn: u32 = (1 << 31) |
        (0b11011101 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SDIV Xd, Xn, Xm (signed divide)
fn emitSdiv(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // SDIV: sf|0|0|11010110|Rm|00001|1|Rn|Rd
    // Encoding: sf|0|0|11010110|Rm[20:16]|00001[15:11]|1[10]|Rn[9:5]|Rd[4:0]
    // Note: bits 15-11 are 00001 for both SDIV and UDIV; bit 10 distinguishes them
    const insn: u32 = (sf_bit << 31) |
        (0b11010110 << 21) |
        (@as(u32, rm) << 16) |
        (0b00001 << 11) |
        (1 << 10) | // bit 10 = 1 for SDIV, 0 for UDIV
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UDIV Xd, Xn, Xm (unsigned divide)
fn emitUdiv(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // UDIV: sf|0|0|11010110|Rm|00001|0|Rn|Rd
    // Encoding: sf|0|0|11010110|Rm[20:16]|00001[15:11]|0[10]|Rn[9:5]|Rd[4:0]
    // Note: bits 15-11 are 00001 for both SDIV and UDIV; bit 10 distinguishes them
    const insn: u32 = (sf_bit << 31) |
        (0b11010110 << 21) |
        (@as(u32, rm) << 16) |
        (0b00001 << 11) |
        (0 << 10) | // bit 10 = 0 for UDIV, 1 for SDIV
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LSL Xd, Xn, Xm (logical shift left, variable)
fn emitLslRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // LSLV (LSL variable): sf|0|0|11010110|Rm|001000|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11010110 << 21) |
        (@as(u32, rm) << 16) |
        (0b001000 << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LSL Xd, Xn, #imm (logical shift left, immediate)
fn emitLslImm(dst: Reg, src: Reg, imm: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const datasize: u8 = if (size == .size64) 64 else 32;

    // LSL is an alias for UBFM (unsigned bitfield move)
    // LSL Xd, Xn, #shift == UBFM Xd, Xn, #(-shift MOD datasize), #(datasize-1-shift)
    const immr: u8 = @truncate((datasize - imm) % datasize);
    const imms: u8 = datasize - 1 - imm;
    const n: u1 = if (size == .size64) 1 else 0;

    // UBFM: sf|10|100110|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b10100110 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, immr) << 16) |
        (@as(u32, imms) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LSR Xd, Xn, Xm (logical shift right, variable)
fn emitLsrRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // LSRV (LSR variable): sf|0|0|11010110|Rm|001001|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11010110 << 21) |
        (@as(u32, rm) << 16) |
        (0b001001 << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LSR Xd, Xn, #imm (logical shift right, immediate)
fn emitLsrImm(dst: Reg, src: Reg, imm: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const datasize: u8 = if (size == .size64) 64 else 32;
    const n: u1 = if (size == .size64) 1 else 0;

    // LSR is an alias for UBFM: LSR Xd, Xn, #shift == UBFM Xd, Xn, #shift, #(datasize-1)
    const immr: u8 = imm;
    const imms: u8 = datasize - 1;

    // UBFM: sf|10|100110|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b10100110 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, immr) << 16) |
        (@as(u32, imms) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ASR Xd, Xn, Xm (arithmetic shift right, variable)
fn emitAsrRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // ASRV (ASR variable): sf|0|0|11010110|Rm|001010|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11010110 << 21) |
        (@as(u32, rm) << 16) |
        (0b001010 << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ASR Xd, Xn, #imm (arithmetic shift right, immediate)
fn emitAsrImm(dst: Reg, src: Reg, imm: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const datasize: u8 = if (size == .size64) 64 else 32;
    const n: u1 = if (size == .size64) 1 else 0;

    // ASR is an alias for SBFM: ASR Xd, Xn, #shift == SBFM Xd, Xn, #shift, #(datasize-1)
    const immr: u8 = imm;
    const imms: u8 = datasize - 1;

    // SBFM: sf|00|100110|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b00100110 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, immr) << 16) |
        (@as(u32, imms) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ROR Xd, Xn, Xm (rotate right, variable)
fn emitRorRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // RORV (ROR variable): sf|0|0|11010110|Rm|001011|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11010110 << 21) |
        (@as(u32, rm) << 16) |
        (0b001011 << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ROR Xd, Xn, #imm (rotate right, immediate)
fn emitRorImm(dst: Reg, src: Reg, imm: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const rs = hwEnc(src); // Source register used twice

    // ROR is an alias for EXTR: ROR Xd, Xn, #shift == EXTR Xd, Xn, Xn, #shift
    const n: u1 = if (size == .size64) 1 else 0;

    // EXTR: sf|00|100111|N|0|Rm|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b00100111 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, rs) << 16) |
        (@as(u32, imm) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// AND Xd, Xn, Xm (bitwise AND register)
fn emitAndRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // AND (shifted register): sf|00|01010|shift|0|Rm|imm6|Rn|Rd
    // Using shift=00 (LSL), imm6=0 (no shift)
    const insn: u32 = (sf_bit << 31) |
        (0b00001010 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// AND Xd, Xn, #imm (bitwise AND immediate)
fn emitAndImm(dst: Reg, src: Reg, imm_logic: root.aarch64_inst.ImmLogic, buffer: *buffer_mod.MachBuffer) !void {
    const size = imm_logic.size;
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const n: u1 = if (imm_logic.n) 1 else 0;

    // AND (immediate): sf|00|100100|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b00100100 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, imm_logic.r) << 16) |
        (@as(u32, imm_logic.s) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ORR Xd, Xn, Xm (bitwise OR register)
fn emitOrrRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // ORR (shifted register): sf|01|01010|shift|0|Rm|imm6|Rn|Rd
    // Using shift=00 (LSL), imm6=0 (no shift)
    const insn: u32 = (sf_bit << 31) |
        (0b01001010 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ORR Xd, Xn, #imm (bitwise OR immediate)
fn emitOrrImm(dst: Reg, src: Reg, imm_logic: root.aarch64_inst.ImmLogic, buffer: *buffer_mod.MachBuffer) !void {
    const size = imm_logic.size;
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const n: u1 = if (imm_logic.n) 1 else 0;

    // ORR (immediate): sf|01|100100|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b01100100 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, imm_logic.r) << 16) |
        (@as(u32, imm_logic.s) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// EOR Xd, Xn, Xm (bitwise XOR register)
fn emitEorRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // EOR (shifted register): sf|10|01010|shift|0|Rm|imm6|Rn|Rd
    // Using shift=00 (LSL), imm6=0 (no shift)
    const insn: u32 = (sf_bit << 31) |
        (0b10001010 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// EOR Xd, Xn, #imm (bitwise XOR immediate)
fn emitEorImm(dst: Reg, src: Reg, imm_logic: root.aarch64_inst.ImmLogic, buffer: *buffer_mod.MachBuffer) !void {
    const size = imm_logic.size;
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const n: u1 = if (imm_logic.n) 1 else 0;

    // EOR (immediate): sf|10|100100|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b10100100 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, imm_logic.r) << 16) |
        (@as(u32, imm_logic.s) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MVN Xd, Xm (bitwise NOT - implemented as ORN Xd, XZR, Xm)
fn emitMvnRR(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rm = hwEnc(src);
    const rn: u5 = 31; // XZR

    // ORN (shifted register): sf|01|01010|shift|1|Rm|imm6|Rn|Rd
    // MVN Xd, Xm == ORN Xd, XZR, Xm with shift=00 (LSL), imm6=0
    // ORN has bit 21 set to distinguish from ORR
    const insn: u32 = (sf_bit << 31) |
        (0b01001010001 << 21) | // ORN opcode (note the extra 1 bit at the end for NOT variant)
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CMP Xn, Xm (compare register with register)
/// Alias for SUBS XZR, Xn, Xm
fn emitCmpRR(src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    // CMP is just SUBS with XZR as destination
    const xzr = if (size == .size64) root.reg.PReg.xzr else root.reg.PReg.wzr;
    const dst = Reg.fromPReg(xzr);
    try emitSubsRR(dst, src1, src2, size, buffer);
}

/// CMP Xn, #imm (compare register with immediate)
/// Alias for SUBS XZR, Xn, #imm
fn emitCmpImm(src: Reg, imm: u16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    // CMP is just SUBS with XZR as destination
    const xzr = if (size == .size64) root.reg.PReg.xzr else root.reg.PReg.wzr;
    const dst = Reg.fromPReg(xzr);
    try emitSubsImm(dst, src, imm, size, buffer);
}

/// CMN Xn, Xm (compare negative)
/// Alias for ADDS XZR, Xn, Xm
fn emitCmnRR(src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    // CMN is just ADDS with XZR as destination
    const xzr = if (size == .size64) root.reg.PReg.xzr else root.reg.PReg.wzr;
    const dst = Reg.fromPReg(xzr);
    try emitAddsRR(dst, src1, src2, size, buffer);
}

/// CMN Xn, #imm (compare negative with immediate)
/// Alias for ADDS XZR, Xn, #imm
fn emitCmnImm(src: Reg, imm: u16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    // CMN is just ADDS with XZR as destination
    const xzr = if (size == .size64) root.reg.PReg.xzr else root.reg.PReg.wzr;
    const dst = Reg.fromPReg(xzr);
    try emitAddsImm(dst, src, imm, size, buffer);
}

/// TST Xn, Xm (test bits)
/// Alias for ANDS XZR, Xn, Xm
fn emitTstRR(src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd: u5 = 31; // XZR
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // ANDS (shifted register): sf|11|01010|shift|0|Rm|imm6|Rn|Rd
    // Using shift=00 (LSL), imm6=0 (no shift)
    const insn: u32 = (sf_bit << 31) |
        (0b11001010 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// TST Xn, #imm (test bits with immediate)
/// Alias for ANDS XZR, Xn, #imm
fn emitTstImm(src: Reg, imm_logic: root.aarch64_inst.ImmLogic, buffer: *buffer_mod.MachBuffer) !void {
    const size = imm_logic.size;
    const sf_bit: u32 = @intCast(sf(size));
    const rd: u5 = 31; // XZR
    const rn = hwEnc(src);
    const n: u1 = if (imm_logic.n) 1 else 0;

    // ANDS (immediate): sf|11|100100|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11100100 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, imm_logic.r) << 16) |
        (@as(u32, imm_logic.s) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CLZ Xd, Xn (count leading zeros)
fn emitClz(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    // CLZ: sf|1|S|11010110|opcode2|opcode|Rn|Rd
    // CLZ: sf|1|0|11010110|00000|00100|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (1 << 30) |
        (0b11010110 << 21) |
        (0b00000 << 16) | // opcode2
        (0b00100 << 10) | // opcode
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CLS Xd, Xn (count leading sign bits)
fn emitCls(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    // CLS: sf|1|S|11010110|opcode2|opcode|Rn|Rd
    // CLS: sf|1|0|11010110|00000|00101|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (1 << 30) |
        (0b11010110 << 21) |
        (0b00000 << 16) | // opcode2
        (0b00101 << 10) | // opcode
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// RBIT Xd, Xn (reverse bits)
fn emitRbit(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    // RBIT: sf|1|S|11010110|opcode2|opcode|Rn|Rd
    // RBIT: sf|1|0|11010110|00000|00000|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (1 << 30) |
        (0b11010110 << 21) |
        (0b00000 << 16) | // opcode2
        (0b00000 << 10) | // opcode
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDR Xt, [Xn, #offset]
fn emitLdr(dst: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    const imm9: u9 = @truncate(@as(u16, @bitCast(offset)));

    // LDR (immediate): sf|11|111|0|00|01|imm9|0|Rn|Rt
    const insn: u32 = (sf_bit << 31) |
        (0b11111000010 << 20) |
        (@as(u32, imm9) << 12) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STR Xt, [Xn, #offset]
fn emitStr(src: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src);
    const rn = hwEnc(base);
    const imm9: u9 = @truncate(@as(u16, @bitCast(offset)));

    // STR (immediate): sf|11|111|0|00|00|imm9|0|Rn|Rt
    const insn: u32 = (sf_bit << 31) |
        (0b11111000000 << 20) |
        (@as(u32, imm9) << 12) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDR Xt, [Xn, Xm] (register offset, no shift)
fn emitLdrReg(dst: Reg, base: Reg, offset: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    const rm = hwEnc(offset);

    // LDR (register): sf|111|0|00|01|Rm|011|0|10|Rn|Rt
    // option=011 (LSL/reserved), S=0 (no scale)
    const insn: u32 = (sf_bit << 31) |
        (0b11100001 << 21) |
        (@as(u32, rm) << 16) |
        (0b011010 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDR Xt, [Xn, Wm, extend] (extended register offset)
fn emitLdrExt(dst: Reg, base: Reg, offset: Reg, extend: Inst.ExtendOp, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    const rm = hwEnc(offset);
    const option: u3 = @intFromEnum(extend);

    // LDR (register, extended): sf|111|0|00|01|Rm|option|S|10|Rn|Rt
    // S=0 (no scale)
    const insn: u32 = (sf_bit << 31) |
        (0b11100001 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, option) << 13) |
        (0b010 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDR Xt, [Xn, Xm, LSL #shift] (scaled register offset)
fn emitLdrScaled(dst: Reg, base: Reg, offset: Reg, shift: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    const rm = hwEnc(offset);
    const s_bit: u1 = if (shift > 0) 1 else 0;

    // LDR (register, scaled): sf|111|0|00|01|Rm|011|S|10|Rn|Rt
    // option=011 (LSL), S=1 (scale by size)
    const insn: u32 = (sf_bit << 31) |
        (0b11100001 << 21) |
        (@as(u32, rm) << 16) |
        (0b011 << 13) |
        (@as(u32, s_bit) << 12) |
        (0b10 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STR Xt, [Xn, Xm] (register offset, no shift)
fn emitStrReg(src: Reg, base: Reg, offset: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src);
    const rn = hwEnc(base);
    const rm = hwEnc(offset);

    // STR (register): sf|111|0|00|00|Rm|011|0|10|Rn|Rt
    // option=011 (LSL/reserved), S=0 (no scale)
    const insn: u32 = (sf_bit << 31) |
        (0b11100000 << 21) |
        (@as(u32, rm) << 16) |
        (0b011010 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STR Xt, [Xn, Wm, extend] (extended register offset)
fn emitStrExt(src: Reg, base: Reg, offset: Reg, extend: Inst.ExtendOp, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src);
    const rn = hwEnc(base);
    const rm = hwEnc(offset);
    const option: u3 = @intFromEnum(extend);

    // STR (register, extended): sf|111|0|00|00|Rm|option|S|10|Rn|Rt
    // S=0 (no scale)
    const insn: u32 = (sf_bit << 31) |
        (0b11100000 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, option) << 13) |
        (0b010 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STR Xt, [Xn, Xm, LSL #shift] (scaled register offset)
fn emitStrScaled(src: Reg, base: Reg, offset: Reg, shift: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src);
    const rn = hwEnc(base);
    const rm = hwEnc(offset);
    const s_bit: u1 = if (shift > 0) 1 else 0;

    // STR (register, scaled): sf|111|0|00|00|Rm|011|S|10|Rn|Rt
    // option=011 (LSL), S=1 (scale by size)
    const insn: u32 = (sf_bit << 31) |
        (0b11100000 << 21) |
        (@as(u32, rm) << 16) |
        (0b011 << 13) |
        (@as(u32, s_bit) << 12) |
        (0b10 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STP Xt1, Xt2, [Xn, #offset]
fn emitStp(src1: Reg, src2: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src1);
    const rt2 = hwEnc(src2);
    const rn = hwEnc(base);
    // Offset is scaled by size: 8 bytes for 64-bit, 4 bytes for 32-bit
    const scale: u4 = if (size == .size64) 3 else 2; // shift by 3 (÷8) for 64-bit, 2 (÷4) for 32-bit
    const imm7: u7 = @truncate(@as(u16, @bitCast(offset)) >> scale);

    // STP: sf|10|1|0|010|0|imm7|Rt2|Rn|Rt
    const insn: u32 = (sf_bit << 31) |
        (0b1010010 << 23) |
        (@as(u32, imm7) << 15) |
        (@as(u32, rt2) << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDP Xt1, Xt2, [Xn, #offset]
fn emitLdp(dst1: Reg, dst2: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst1);
    const rt2 = hwEnc(dst2);
    const rn = hwEnc(base);
    // Offset is scaled by size: 8 bytes for 64-bit, 4 bytes for 32-bit
    const scale: u4 = if (size == .size64) 3 else 2; // shift by 3 (÷8) for 64-bit, 2 (÷4) for 32-bit
    const imm7: u7 = @truncate(@as(u16, @bitCast(offset)) >> scale);

    // LDP: sf|10|1|0|011|0|imm7|Rt2|Rn|Rt
    const insn: u32 = (sf_bit << 31) |
        (0b1010011 << 23) |
        (@as(u32, imm7) << 15) |
        (@as(u32, rt2) << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// B label (unconditional branch)
fn emitB(label: u32, buffer: *buffer_mod.MachBuffer) !void {
    // B: 0|00101|imm26
    const insn: u32 = (0b00101 << 26);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);

    // Add label use for fixup
    try buffer.useLabel(
        buffer_mod.MachLabel.new(label),
        buffer_mod.LabelUseKind.branch26,
    );
}

/// B.cond label (conditional branch)
fn emitBCond(cond: u8, label: u32, buffer: *buffer_mod.MachBuffer) !void {
    // B.cond: 01010100|imm19|0|cond
    const insn: u32 = (0b01010100 << 24) | @as(u32, cond);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);

    // Add label use for fixup
    try buffer.useLabel(
        buffer_mod.MachLabel.new(label),
        buffer_mod.LabelUseKind.branch19,
    );
}

/// BL label (branch and link)
fn emitBL(label: u32, buffer: *buffer_mod.MachBuffer) !void {
    // BL: 1|00101|imm26
    const insn: u32 = (0b100101 << 26);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);

    // Add label use for fixup
    try buffer.useLabel(
        buffer_mod.MachLabel.new(label),
        buffer_mod.LabelUseKind.branch26,
    );
}

/// BR Xn (branch to register)
fn emitBR(target: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rn = hwEnc(target);

    // BR: 1101011|0000|11111|000000|Rn|00000
    const insn: u32 = (0b1101011000011111000000 << 10) |
        (@as(u32, rn) << 5);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// BLR Xn (branch and link to register)
fn emitBLR(target: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rn = hwEnc(target);

    // BLR: 1101011|0001|11111|000000|Rn|00000
    const insn: u32 = (0b1101011000111111000000 << 10) |
        (@as(u32, rn) << 5);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// RET [Xn] (return from subroutine)
fn emitRet(reg: ?Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rn = if (reg) |r| hwEnc(r) else 30; // Default to X30 (LR)

    // RET: 1101011|0010|11111|000000|Rn|00000
    const insn: u32 = (0b1101011001011111000000 << 10) |
        (@as(u32, rn) << 5);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// NOP
fn emitNop(buffer: *buffer_mod.MachBuffer) !void {
    // NOP: 11010101000000110010000011111111
    const insn: u32 = 0xD503201F;
    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

test "emit nop" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try emit(.nop, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    try testing.expectEqual(@as(u32, 0xD503201F), std.mem.bytesToValue(u32, buffer.data.items[0..4]));
}

test "emit ret" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try emit(.{ .ret = .{ .reg = null } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    // RET defaults to X30
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 30), (insn >> 5) & 0x1F);
}

test "emit mov imm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .mov_imm = .{
        .dst = wr0,
        .imm = 42,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31)
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check immediate (bits 5-20)
    try testing.expectEqual(@as(u32, 42), (insn >> 5) & 0xFFFF);
}

test "emit add rr" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .add_rr = .{
        .dst = wr0,
        .src1 = r0,
        .src2 = r1,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

test "emit mul rr" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .mul_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode field (bits 21-28) = 0b11011000
    try testing.expectEqual(@as(u32, 0b11011000), (insn >> 21) & 0xFF);

    // Check Ra field (bits 10-14) = 31 (XZR)
    try testing.expectEqual(@as(u32, 31), (insn >> 10) & 0x1F);
}

test "emit madd" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const v3 = root.reg.VReg.new(3, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const r3 = Reg.fromVReg(v3);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .madd = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .addend = r3,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check opcode field
    try testing.expectEqual(@as(u32, 0b11011000), (insn >> 21) & 0xFF);

    // Check o0 bit (bit 15) = 0 for MADD
    try testing.expectEqual(@as(u32, 0), (insn >> 15) & 1);
}

test "emit msub" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const v3 = root.reg.VReg.new(3, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const r3 = Reg.fromVReg(v3);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .msub = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .subtrahend = r3,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check o0 bit (bit 15) = 1 for MSUB
    try testing.expectEqual(@as(u32, 1), (insn >> 15) & 1);
}

test "emit smulh" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .smulh = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 (always 64-bit)
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode field (bits 21-28) = 0b11011010
    try testing.expectEqual(@as(u32, 0b11011010), (insn >> 21) & 0xFF);
}

test "emit umulh" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .umulh = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check opcode field (bits 21-28) = 0b11011110
    try testing.expectEqual(@as(u32, 0b11011110), (insn >> 21) & 0xFF);
}

test "emit sdiv 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r10 = Reg.fromVReg(v10);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // SDIV X3, X10, X5
    try emit(.{ .sdiv = .{
        .dst = wr3,
        .src1 = r10,
        .src2 = r5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check bits 30-29 = 0b00
    try testing.expectEqual(@as(u32, 0b00), (insn >> 29) & 0b11);

    // Check opcode field (bits 21-28) = 0b11010110
    try testing.expectEqual(@as(u32, 0b11010110), (insn >> 21) & 0xFF);

    // Check Rm field (bits 16-20) = 5
    try testing.expectEqual(@as(u32, 5), (insn >> 16) & 0x1F);

    // Check opcode2 field (bits 11-15) = 0b00001 for SDIV
    try testing.expectEqual(@as(u32, 0b00001), (insn >> 11) & 0x1F);

    // Check bit 10 = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 10) & 1);

    // Check Rn field (bits 5-9) = 10
    try testing.expectEqual(@as(u32, 10), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 3
    try testing.expectEqual(@as(u32, 3), insn & 0x1F);

    // Verify complete encoding: 0x9AC50D43
    try testing.expectEqual(@as(u32, 0x9AC50D43), insn);
}

test "emit sdiv 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r10 = Reg.fromVReg(v10);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // SDIV W3, W10, W5
    try emit(.{ .sdiv = .{
        .dst = wr3,
        .src1 = r10,
        .src2 = r5,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check opcode field (bits 21-28) = 0b11010110
    try testing.expectEqual(@as(u32, 0b11010110), (insn >> 21) & 0xFF);

    // Check opcode2 field (bits 11-15) = 0b00001 for SDIV
    try testing.expectEqual(@as(u32, 0b00001), (insn >> 11) & 0x1F);

    // Verify complete encoding: 0x1AC50D43
    try testing.expectEqual(@as(u32, 0x1AC50D43), insn);
}

test "emit udiv 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r10 = Reg.fromVReg(v10);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // UDIV X3, X10, X5
    try emit(.{ .udiv = .{
        .dst = wr3,
        .src1 = r10,
        .src2 = r5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check bits 30-29 = 0b00
    try testing.expectEqual(@as(u32, 0b00), (insn >> 29) & 0b11);

    // Check opcode field (bits 21-28) = 0b11010110
    try testing.expectEqual(@as(u32, 0b11010110), (insn >> 21) & 0xFF);

    // Check Rm field (bits 16-20) = 5
    try testing.expectEqual(@as(u32, 5), (insn >> 16) & 0x1F);

    // Check bits 15-11 = 0b00001 (same as SDIV)
    try testing.expectEqual(@as(u32, 0b00001), (insn >> 11) & 0x1F);

    // Check bit 10 = 0 for UDIV (distinguishes from SDIV)
    try testing.expectEqual(@as(u32, 0), (insn >> 10) & 1);

    // Check Rn field (bits 5-9) = 10
    try testing.expectEqual(@as(u32, 10), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 3
    try testing.expectEqual(@as(u32, 3), insn & 0x1F);

    // Verify complete encoding: 0x9AC50943
    try testing.expectEqual(@as(u32, 0x9AC50943), insn);
}

test "emit udiv 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r10 = Reg.fromVReg(v10);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // UDIV W3, W10, W5
    try emit(.{ .udiv = .{
        .dst = wr3,
        .src1 = r10,
        .src2 = r5,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check opcode field (bits 21-28) = 0b11010110
    try testing.expectEqual(@as(u32, 0b11010110), (insn >> 21) & 0xFF);

    // Check bits 15-11 = 0b00001 (same as SDIV)
    try testing.expectEqual(@as(u32, 0b00001), (insn >> 11) & 0x1F);

    // Check bit 10 = 0 for UDIV
    try testing.expectEqual(@as(u32, 0), (insn >> 10) & 1);

    // Verify complete encoding: 0x1AC50943
    try testing.expectEqual(@as(u32, 0x1AC50943), insn);
}

test "emit divide with different registers" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // SDIV X0, X1, X2
    try emit(.{ .sdiv = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check Rd = 0, Rn = 1, Rm = 2
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F);
}

test "emit and rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // AND X0, X1, X2
    try emit(.{ .and_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 29-21) = 0b00001010 for AND
    try testing.expectEqual(@as(u32, 0b00001010), (insn >> 21) & 0x3FF);

    // Check Rd = 0, Rn = 1, Rm = 2
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F);
}

test "emit and rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const r5 = Reg.fromVReg(v5);
    const r10 = Reg.fromVReg(v10);
    const r7 = Reg.fromVReg(v7);
    const wr5 = root.reg.WritableReg.fromReg(r5);

    // AND W5, W10, W7
    try emit(.{ .and_rr = .{
        .dst = wr5,
        .src1 = r10,
        .src2 = r7,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x0A070145 (AND W5, W10, W7)
    try testing.expectEqual(@as(u32, 0x0A070145), insn);
}

test "emit and imm 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r1 = Reg.fromVReg(v1);
    const wr2 = root.reg.WritableReg.fromReg(Reg.fromVReg(v2));

    // AND X2, X1, #0xff (example with simple bitmask)
    const imm_logic = root.aarch64_inst.ImmLogic{
        .value = 0xff,
        .n = true, // N=1 for 64-bit patterns
        .r = 0, // immr
        .s = 7, // imms (8 consecutive 1s)
        .size = .size64,
    };

    try emit(.{ .and_imm = .{
        .dst = wr2,
        .src = r1,
        .imm = imm_logic,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 29-23) = 0b00100100 for AND immediate
    try testing.expectEqual(@as(u32, 0b00100100), (insn >> 23) & 0x7F);

    // Check N bit
    try testing.expectEqual(@as(u32, 1), (insn >> 22) & 1);

    // Check immr and imms fields
    try testing.expectEqual(@as(u32, 0), (insn >> 16) & 0x3F);
    try testing.expectEqual(@as(u32, 7), (insn >> 10) & 0x3F);

    // Check registers
    try testing.expectEqual(@as(u32, 2), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
}

test "emit orr rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // ORR X3, X4, X5
    try emit(.{ .orr_rr = .{
        .dst = wr3,
        .src1 = r4,
        .src2 = r5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 29-21) = 0b01001010 for ORR
    try testing.expectEqual(@as(u32, 0b01001010), (insn >> 21) & 0x3FF);

    // Verify complete encoding: 0xAA050083 (ORR X3, X4, X5)
    try testing.expectEqual(@as(u32, 0xAA050083), insn);
}

test "emit eor rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);
    const wr6 = root.reg.WritableReg.fromReg(r6);

    // EOR X6, X7, X8
    try emit(.{ .eor_rr = .{
        .dst = wr6,
        .src1 = r7,
        .src2 = r8,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 29-21) = 0b10001010 for EOR
    try testing.expectEqual(@as(u32, 0b10001010), (insn >> 21) & 0x3FF);

    // Verify complete encoding: 0xCA0800E6 (EOR X6, X7, X8)
    try testing.expectEqual(@as(u32, 0xCA0800E6), insn);
}

test "emit mvn rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v9 = root.reg.VReg.new(9, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const r9 = Reg.fromVReg(v9);
    const r10 = Reg.fromVReg(v10);
    const wr9 = root.reg.WritableReg.fromReg(r9);

    // MVN X9, X10 (implemented as ORN X9, XZR, X10)
    try emit(.{ .mvn_rr = .{
        .dst = wr9,
        .src = r10,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode for ORN (bits 29-21 should be 0b01001010001)
    // Note: ORN has bit 21 set compared to ORR
    try testing.expectEqual(@as(u32, 0b01001010001), (insn >> 21) & 0x7FF);

    // Check Rn = 31 (XZR)
    try testing.expectEqual(@as(u32, 31), (insn >> 5) & 0x1F);

    // Check Rm = 10 and Rd = 9
    try testing.expectEqual(@as(u32, 10), (insn >> 16) & 0x1F);
    try testing.expectEqual(@as(u32, 9), insn & 0x1F);

    // Verify complete encoding: 0xAA2A03E9 (ORN X9, XZR, X10 == MVN X9, X10)
    try testing.expectEqual(@as(u32, 0xAA2A03E9), insn);
}

test "emit mvn rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // MVN W0, W1
    try emit(.{ .mvn_rr = .{
        .dst = wr0,
        .src = r1,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x2A2103E0 (ORN W0, WZR, W1 == MVN W0, W1)
    try testing.expectEqual(@as(u32, 0x2A2103E0), insn);
}

test "emit adds rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // ADDS X0, X1, X2
    try emit(.{ .adds_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for ADDS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b0101011 for ADD/ADDS
    try testing.expectEqual(@as(u32, 0b0101011), (insn >> 24) & 0x7F);

    // Check Rd = 0, Rn = 1, Rm = 2
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F);

    // Verify complete encoding: 0xAB020020 (ADDS X0, X1, X2)
    try testing.expectEqual(@as(u32, 0xAB020020), insn);
}

test "emit adds rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // ADDS W3, W4, W5
    try emit(.{ .adds_rr = .{
        .dst = wr3,
        .src1 = r4,
        .src2 = r5,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for ADDS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Verify complete encoding: 0x2B050083 (ADDS W3, W4, W5)
    try testing.expectEqual(@as(u32, 0x2B050083), insn);
}

test "emit adds imm 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const wr10 = root.reg.WritableReg.fromReg(r10);

    // ADDS X10, X11, #42
    try emit(.{ .adds_imm = .{
        .dst = wr10,
        .src = r11,
        .imm = 42,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for ADDS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b0100010 for immediate form
    try testing.expectEqual(@as(u32, 0b0100010), (insn >> 24) & 0x7F);

    // Check immediate value = 42
    try testing.expectEqual(@as(u32, 42), (insn >> 10) & 0xFFF);

    // Check Rd = 10, Rn = 11
    try testing.expectEqual(@as(u32, 10), insn & 0x1F);
    try testing.expectEqual(@as(u32, 11), (insn >> 5) & 0x1F);

    // Verify complete encoding: 0xB100A96A (ADDS X10, X11, #42)
    try testing.expectEqual(@as(u32, 0xB100A96A), insn);
}

test "emit adds imm 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const v21 = root.reg.VReg.new(21, .int);
    const r20 = Reg.fromVReg(v20);
    const r21 = Reg.fromVReg(v21);
    const wr20 = root.reg.WritableReg.fromReg(r20);

    // ADDS W20, W21, #100
    try emit(.{ .adds_imm = .{
        .dst = wr20,
        .src = r21,
        .imm = 100,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for ADDS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check immediate value = 100
    try testing.expectEqual(@as(u32, 100), (insn >> 10) & 0xFFF);

    // Verify complete encoding: 0x310192B4 (ADDS W20, W21, #100)
    try testing.expectEqual(@as(u32, 0x310192B4), insn);
}

test "emit subs rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);
    const wr6 = root.reg.WritableReg.fromReg(r6);

    // SUBS X6, X7, X8
    try emit(.{ .subs_rr = .{
        .dst = wr6,
        .src1 = r7,
        .src2 = r8,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for SUBS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b1101011 for SUB/SUBS
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 24) & 0x7F);

    // Check Rd = 6, Rn = 7, Rm = 8
    try testing.expectEqual(@as(u32, 6), insn & 0x1F);
    try testing.expectEqual(@as(u32, 7), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 8), (insn >> 16) & 0x1F);

    // Verify complete encoding: 0xEB0800E6 (SUBS X6, X7, X8)
    try testing.expectEqual(@as(u32, 0xEB0800E6), insn);
}

test "emit subs rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v12 = root.reg.VReg.new(12, .int);
    const v13 = root.reg.VReg.new(13, .int);
    const v14 = root.reg.VReg.new(14, .int);
    const r12 = Reg.fromVReg(v12);
    const r13 = Reg.fromVReg(v13);
    const r14 = Reg.fromVReg(v14);
    const wr12 = root.reg.WritableReg.fromReg(r12);

    // SUBS W12, W13, W14
    try emit(.{ .subs_rr = .{
        .dst = wr12,
        .src1 = r13,
        .src2 = r14,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for SUBS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Verify complete encoding: 0x6B0E01AC (SUBS W12, W13, W14)
    try testing.expectEqual(@as(u32, 0x6B0E01AC), insn);
}

test "emit subs imm 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v15 = root.reg.VReg.new(15, .int);
    const v16 = root.reg.VReg.new(16, .int);
    const r15 = Reg.fromVReg(v15);
    const r16 = Reg.fromVReg(v16);
    const wr15 = root.reg.WritableReg.fromReg(r15);

    // SUBS X15, X16, #777
    try emit(.{ .subs_imm = .{
        .dst = wr15,
        .src = r16,
        .imm = 777,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for SUBS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b1100010 for immediate form
    try testing.expectEqual(@as(u32, 0b1100010), (insn >> 24) & 0x7F);

    // Check immediate value = 777
    try testing.expectEqual(@as(u32, 777), (insn >> 10) & 0xFFF);

    // Check Rd = 15, Rn = 16
    try testing.expectEqual(@as(u32, 15), insn & 0x1F);
    try testing.expectEqual(@as(u32, 16), (insn >> 5) & 0x1F);

    // Verify complete encoding: 0xF10C260F (SUBS X15, X16, #777)
    try testing.expectEqual(@as(u32, 0xF10C260F), insn);
}

test "emit subs imm 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v25 = root.reg.VReg.new(25, .int);
    const v26 = root.reg.VReg.new(26, .int);
    const r25 = Reg.fromVReg(v25);
    const r26 = Reg.fromVReg(v26);
    const wr25 = root.reg.WritableReg.fromReg(r25);

    // SUBS W25, W26, #999
    try emit(.{ .subs_imm = .{
        .dst = wr25,
        .src = r26,
        .imm = 999,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for SUBS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check immediate value = 999
    try testing.expectEqual(@as(u32, 999), (insn >> 10) & 0xFFF);

    // Verify complete encoding: 0x710F9F59 (SUBS W25, W26, #999)
    try testing.expectEqual(@as(u32, 0x710F9F59), insn);
}

test "emit cmp rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    // CMP X1, X2 (alias for SUBS XZR, X1, X2)
    try emit(.{ .cmp_rr = .{
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for SUBS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b1101011 for SUB/SUBS
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 24) & 0x7F);

    // Check Rd = 31 (XZR), Rn = 1, Rm = 2
    try testing.expectEqual(@as(u32, 31), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F);

    // Verify complete encoding: 0xEB02003F (SUBS XZR, X1, X2 == CMP X1, X2)
    try testing.expectEqual(@as(u32, 0xEB02003F), insn);
}

test "emit cmp rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const r5 = Reg.fromVReg(v5);
    const r10 = Reg.fromVReg(v10);

    // CMP W5, W10
    try emit(.{ .cmp_rr = .{
        .src1 = r5,
        .src2 = r10,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x6B0A00BF (SUBS WZR, W5, W10 == CMP W5, W10)
    try testing.expectEqual(@as(u32, 0x6B0A00BF), insn);
}

test "emit cmp imm 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const r3 = Reg.fromVReg(v3);

    // CMP X3, #42 (alias for SUBS XZR, X3, #42)
    try emit(.{ .cmp_imm = .{
        .src = r3,
        .imm = 42,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for SUBS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b1100010 for immediate form
    try testing.expectEqual(@as(u32, 0b1100010), (insn >> 24) & 0x7F);

    // Check immediate value = 42
    try testing.expectEqual(@as(u32, 42), (insn >> 10) & 0xFFF);

    // Check Rd = 31 (XZR), Rn = 3
    try testing.expectEqual(@as(u32, 31), insn & 0x1F);
    try testing.expectEqual(@as(u32, 3), (insn >> 5) & 0x1F);

    // Verify complete encoding: 0xF1002A7F (SUBS XZR, X3, #42 == CMP X3, #42)
    try testing.expectEqual(@as(u32, 0xF1002A7F), insn);
}

test "emit cmp imm 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v7 = root.reg.VReg.new(7, .int);
    const r7 = Reg.fromVReg(v7);

    // CMP W7, #100
    try emit(.{ .cmp_imm = .{
        .src = r7,
        .imm = 100,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check immediate value = 100
    try testing.expectEqual(@as(u32, 100), (insn >> 10) & 0xFFF);

    // Verify complete encoding: 0x710190FF (SUBS WZR, W7, #100 == CMP W7, #100)
    try testing.expectEqual(@as(u32, 0x710190FF), insn);
}

test "emit cmn rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v8 = root.reg.VReg.new(8, .int);
    const v9 = root.reg.VReg.new(9, .int);
    const r8 = Reg.fromVReg(v8);
    const r9 = Reg.fromVReg(v9);

    // CMN X8, X9 (alias for ADDS XZR, X8, X9)
    try emit(.{ .cmn_rr = .{
        .src1 = r8,
        .src2 = r9,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for ADDS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b0101011 for ADD/ADDS
    try testing.expectEqual(@as(u32, 0b0101011), (insn >> 24) & 0x7F);

    // Check Rd = 31 (XZR), Rn = 8, Rm = 9
    try testing.expectEqual(@as(u32, 31), insn & 0x1F);
    try testing.expectEqual(@as(u32, 8), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 9), (insn >> 16) & 0x1F);

    // Verify complete encoding: 0xAB09011F (ADDS XZR, X8, X9 == CMN X8, X9)
    try testing.expectEqual(@as(u32, 0xAB09011F), insn);
}

test "emit cmn rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);

    // CMN W0, W1
    try emit(.{ .cmn_rr = .{
        .src1 = r0,
        .src2 = r1,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x2B01001F (ADDS WZR, W0, W1 == CMN W0, W1)
    try testing.expectEqual(@as(u32, 0x2B01001F), insn);
}

test "emit cmn imm 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v15 = root.reg.VReg.new(15, .int);
    const r15 = Reg.fromVReg(v15);

    // CMN X15, #255 (alias for ADDS XZR, X15, #255)
    try emit(.{ .cmn_imm = .{
        .src = r15,
        .imm = 255,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for ADDS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b0100010 for immediate form
    try testing.expectEqual(@as(u32, 0b0100010), (insn >> 24) & 0x7F);

    // Check immediate value = 255
    try testing.expectEqual(@as(u32, 255), (insn >> 10) & 0xFFF);

    // Check Rd = 31 (XZR), Rn = 15
    try testing.expectEqual(@as(u32, 31), insn & 0x1F);
    try testing.expectEqual(@as(u32, 15), (insn >> 5) & 0x1F);

    // Verify complete encoding: 0xB1003FFF (ADDS XZR, X15, #255 == CMN X15, #255)
    try testing.expectEqual(@as(u32, 0xB1003FFF), insn);
}

test "emit cmn imm 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const r20 = Reg.fromVReg(v20);

    // CMN W20, #1
    try emit(.{ .cmn_imm = .{
        .src = r20,
        .imm = 1,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check immediate value = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 10) & 0xFFF);

    // Verify complete encoding: 0x3100069F (ADDS WZR, W20, #1 == CMN W20, #1)
    try testing.expectEqual(@as(u32, 0x3100069F), insn);
}

test "emit tst rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v12 = root.reg.VReg.new(12, .int);
    const v13 = root.reg.VReg.new(13, .int);
    const r12 = Reg.fromVReg(v12);
    const r13 = Reg.fromVReg(v13);

    // TST X12, X13 (alias for ANDS XZR, X12, X13)
    try emit(.{ .tst_rr = .{
        .src1 = r12,
        .src2 = r13,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 29-21) = 0b11001010 for ANDS
    try testing.expectEqual(@as(u32, 0b11001010), (insn >> 21) & 0x3FF);

    // Check Rd = 31 (XZR), Rn = 12, Rm = 13
    try testing.expectEqual(@as(u32, 31), insn & 0x1F);
    try testing.expectEqual(@as(u32, 12), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 13), (insn >> 16) & 0x1F);

    // Verify complete encoding: 0xEA0D019F (ANDS XZR, X12, X13 == TST X12, X13)
    try testing.expectEqual(@as(u32, 0xEA0D019F), insn);
}

test "emit tst rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v25 = root.reg.VReg.new(25, .int);
    const v30 = root.reg.VReg.new(30, .int);
    const r25 = Reg.fromVReg(v25);
    const r30 = Reg.fromVReg(v30);

    // TST W25, W30
    try emit(.{ .tst_rr = .{
        .src1 = r25,
        .src2 = r30,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x6A1E033F (ANDS WZR, W25, W30 == TST W25, W30)
    try testing.expectEqual(@as(u32, 0x6A1E033F), insn);
}

test "emit tst imm 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v4 = root.reg.VReg.new(4, .int);
    const r4 = Reg.fromVReg(v4);

    // TST X4, #0xff (alias for ANDS XZR, X4, #0xff)
    const imm_logic = root.aarch64_inst.ImmLogic{
        .value = 0xff,
        .n = true, // N=1 for 64-bit patterns
        .r = 0, // immr
        .s = 7, // imms (8 consecutive 1s)
        .size = .size64,
    };

    try emit(.{ .tst_imm = .{
        .src = r4,
        .imm = imm_logic,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 29-23) = 0b11100100 for ANDS immediate
    try testing.expectEqual(@as(u32, 0b11100100), (insn >> 23) & 0x7F);

    // Check N bit
    try testing.expectEqual(@as(u32, 1), (insn >> 22) & 1);

    // Check immr and imms fields
    try testing.expectEqual(@as(u32, 0), (insn >> 16) & 0x3F);
    try testing.expectEqual(@as(u32, 7), (insn >> 10) & 0x3F);

    // Check Rd = 31 (XZR), Rn = 4
    try testing.expectEqual(@as(u32, 31), insn & 0x1F);
    try testing.expectEqual(@as(u32, 4), (insn >> 5) & 0x1F);

    // Verify complete encoding: 0xF240109F (ANDS XZR, X4, #0xff == TST X4, #0xff)
    try testing.expectEqual(@as(u32, 0xF240109F), insn);
}

test "emit tst imm 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const r6 = Reg.fromVReg(v6);

    // TST W6, #0xf (test lower 4 bits)
    const imm_logic = root.aarch64_inst.ImmLogic{
        .value = 0xf,
        .n = false, // N=0 for 32-bit patterns
        .r = 0, // immr
        .s = 3, // imms (4 consecutive 1s)
        .size = .size32,
    };

    try emit(.{ .tst_imm = .{
        .src = r6,
        .imm = imm_logic,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check N bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 22) & 1);

    // Check immr = 0, imms = 3
    try testing.expectEqual(@as(u32, 0), (insn >> 16) & 0x3F);
    try testing.expectEqual(@as(u32, 3), (insn >> 10) & 0x3F);

    // Verify complete encoding: 0x72000CDF (ANDS WZR, W6, #0xf == TST W6, #0xf)
    try testing.expectEqual(@as(u32, 0x72000CDF), insn);
}

test "emit lsl register 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSLV X0, X1, X2
    try emit(.{ .lsl_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode field (bits 21-28) = 0b11010110
    try testing.expectEqual(@as(u32, 0b11010110), (insn >> 21) & 0xFF);

    // Check opcode2 field (bits 10-15) = 0b001000 for LSLV
    try testing.expectEqual(@as(u32, 0b001000), (insn >> 10) & 0x3F);

    // Check Rd = 0, Rn = 1, Rm = 2
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F);

    // Verify complete encoding: 0x9AC22020
    try testing.expectEqual(@as(u32, 0x9AC22020), insn);
}

test "emit lsl register 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSLV W0, W1, W2
    try emit(.{ .lsl_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x1AC22020
    try testing.expectEqual(@as(u32, 0x1AC22020), insn);
}

test "emit lsl immediate 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSL X0, X1, #5
    try emit(.{ .lsl_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 23-30) = 0b10100110
    try testing.expectEqual(@as(u32, 0b10100110), (insn >> 23) & 0xFF);

    // Check N bit (bit 22) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 22) & 1);

    // Verify complete encoding: 0xD37BEC20 (immr=59, imms=58)
    try testing.expectEqual(@as(u32, 0xD37BEC20), insn);
}

test "emit lsl immediate 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSL W0, W1, #5
    try emit(.{ .lsl_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 5,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x531B6C20 (immr=27, imms=26)
    try testing.expectEqual(@as(u32, 0x531B6C20), insn);
}

test "emit lsr register 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSRV X0, X1, X2
    try emit(.{ .lsr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode2 field (bits 10-15) = 0b001001 for LSRV
    try testing.expectEqual(@as(u32, 0b001001), (insn >> 10) & 0x3F);

    // Verify complete encoding: 0x9AC22420
    try testing.expectEqual(@as(u32, 0x9AC22420), insn);
}

test "emit lsr immediate 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSR X0, X1, #5
    try emit(.{ .lsr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Verify complete encoding: 0xD345FC20 (immr=5, imms=63)
    try testing.expectEqual(@as(u32, 0xD345FC20), insn);
}

test "emit asr register 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // ASRV X0, X1, X2
    try emit(.{ .asr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode2 field (bits 10-15) = 0b001010 for ASRV
    try testing.expectEqual(@as(u32, 0b001010), (insn >> 10) & 0x3F);

    // Verify complete encoding: 0x9AC22820
    try testing.expectEqual(@as(u32, 0x9AC22820), insn);
}

test "emit asr immediate 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // ASR X0, X1, #5
    try emit(.{ .asr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 23-30) = 0b00100110 (SBFM)
    try testing.expectEqual(@as(u32, 0b00100110), (insn >> 23) & 0xFF);

    // Verify complete encoding: 0x9345FC20 (immr=5, imms=63)
    try testing.expectEqual(@as(u32, 0x9345FC20), insn);
}

test "emit ror register 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // RORV X0, X1, X2
    try emit(.{ .ror_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode2 field (bits 10-15) = 0b001011 for RORV
    try testing.expectEqual(@as(u32, 0b001011), (insn >> 10) & 0x3F);

    // Verify complete encoding: 0x9AC22C20
    try testing.expectEqual(@as(u32, 0x9AC22C20), insn);
}

test "emit ror immediate 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // ROR X0, X1, #5
    try emit(.{ .ror_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 23-30) = 0b00100111 (EXTR)
    try testing.expectEqual(@as(u32, 0b00100111), (insn >> 23) & 0xFF);

    // Verify complete encoding: 0x93C11420 (Rm=Rn=1, imms=5)
    try testing.expectEqual(@as(u32, 0x93C11420), insn);
}

test "emit ror immediate 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // ROR W0, W1, #16
    try emit(.{ .ror_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 16,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x13814020 (Rm=Rn=1, imms=16)
    try testing.expectEqual(@as(u32, 0x13814020), insn);
}

test "emit shift with edge cases" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSL X0, X1, #0 (shift by 0)
    try emit(.{ .lsl_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 0,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    var insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // immr = (64 - 0) % 64 = 0, imms = 63
    try testing.expectEqual(@as(u32, 0xD340FC20), insn);

    buffer.data.clearRetainingCapacity();

    // LSR X0, X1, #63 (maximum shift for 64-bit)
    try emit(.{ .lsr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 63,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify encoding: immr=63, imms=63
    try testing.expectEqual(@as(u32, 0xD37FFC20), insn);

    buffer.data.clearRetainingCapacity();

    // LSR W0, W1, #31 (maximum shift for 32-bit)
    try emit(.{ .lsr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 31,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify encoding: immr=31, imms=31
    try testing.expectEqual(@as(u32, 0x537F7C20), insn);
}

test "emit clz 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // CLZ X0, X1
    try emit(.{ .clz = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check fixed bits (bits 30-21) = 0b1011010110
    try testing.expectEqual(@as(u32, 0b1011010110), (insn >> 21) & 0x3FF);

    // Check opcode2 field (bits 16-20) = 0b00000
    try testing.expectEqual(@as(u32, 0b00000), (insn >> 16) & 0x1F);

    // Check opcode field (bits 10-15) = 0b00100
    try testing.expectEqual(@as(u32, 0b00100), (insn >> 10) & 0x3F);

    // Check Rn field (bits 5-9) = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 0
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);

    // Verify complete encoding: 0xDAC01020
    try testing.expectEqual(@as(u32, 0xDAC01020), insn);
}

test "emit clz 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // CLZ W3, W5
    try emit(.{ .clz = .{
        .dst = wr3,
        .src = r5,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check fixed bits (bits 30-21) = 0b1011010110
    try testing.expectEqual(@as(u32, 0b1011010110), (insn >> 21) & 0x3FF);

    // Check opcode field (bits 10-15) = 0b00100
    try testing.expectEqual(@as(u32, 0b00100), (insn >> 10) & 0x3F);

    // Check Rn field (bits 5-9) = 5
    try testing.expectEqual(@as(u32, 5), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 3
    try testing.expectEqual(@as(u32, 3), insn & 0x1F);

    // Verify complete encoding: 0x5AC010A3
    try testing.expectEqual(@as(u32, 0x5AC010A3), insn);
}

test "emit cls 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v2 = root.reg.VReg.new(2, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const r2 = Reg.fromVReg(v2);
    const r7 = Reg.fromVReg(v7);
    const wr2 = root.reg.WritableReg.fromReg(r2);

    // CLS X2, X7
    try emit(.{ .cls = .{
        .dst = wr2,
        .src = r7,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check fixed bits (bits 30-21) = 0b1011010110
    try testing.expectEqual(@as(u32, 0b1011010110), (insn >> 21) & 0x3FF);

    // Check opcode2 field (bits 16-20) = 0b00000
    try testing.expectEqual(@as(u32, 0b00000), (insn >> 16) & 0x1F);

    // Check opcode field (bits 10-15) = 0b00101
    try testing.expectEqual(@as(u32, 0b00101), (insn >> 10) & 0x3F);

    // Check Rn field (bits 5-9) = 7
    try testing.expectEqual(@as(u32, 7), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 2
    try testing.expectEqual(@as(u32, 2), insn & 0x1F);

    // Verify complete encoding: 0xDAC014E2
    try testing.expectEqual(@as(u32, 0xDAC014E2), insn);
}

test "emit cls 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v15 = root.reg.VReg.new(15, .int);
    const r10 = Reg.fromVReg(v10);
    const r15 = Reg.fromVReg(v15);
    const wr10 = root.reg.WritableReg.fromReg(r10);

    // CLS W10, W15
    try emit(.{ .cls = .{
        .dst = wr10,
        .src = r15,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check fixed bits (bits 30-21) = 0b1011010110
    try testing.expectEqual(@as(u32, 0b1011010110), (insn >> 21) & 0x3FF);

    // Check opcode field (bits 10-15) = 0b00101
    try testing.expectEqual(@as(u32, 0b00101), (insn >> 10) & 0x3F);

    // Check Rn field (bits 5-9) = 15
    try testing.expectEqual(@as(u32, 15), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 10
    try testing.expectEqual(@as(u32, 10), insn & 0x1F);

    // Verify complete encoding: 0x5AC015EA
    try testing.expectEqual(@as(u32, 0x5AC015EA), insn);
}

test "emit rbit 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v4 = root.reg.VReg.new(4, .int);
    const v9 = root.reg.VReg.new(9, .int);
    const r4 = Reg.fromVReg(v4);
    const r9 = Reg.fromVReg(v9);
    const wr4 = root.reg.WritableReg.fromReg(r4);

    // RBIT X4, X9
    try emit(.{ .rbit = .{
        .dst = wr4,
        .src = r9,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check fixed bits (bits 30-21) = 0b1011010110
    try testing.expectEqual(@as(u32, 0b1011010110), (insn >> 21) & 0x3FF);

    // Check opcode2 field (bits 16-20) = 0b00000
    try testing.expectEqual(@as(u32, 0b00000), (insn >> 16) & 0x1F);

    // Check opcode field (bits 10-15) = 0b00000
    try testing.expectEqual(@as(u32, 0b00000), (insn >> 10) & 0x3F);

    // Check Rn field (bits 5-9) = 9
    try testing.expectEqual(@as(u32, 9), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 4
    try testing.expectEqual(@as(u32, 4), insn & 0x1F);

    // Verify complete encoding: 0xDAC00124
    try testing.expectEqual(@as(u32, 0xDAC00124), insn);
}

test "emit rbit 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v8 = root.reg.VReg.new(8, .int);
    const v12 = root.reg.VReg.new(12, .int);
    const r8 = Reg.fromVReg(v8);
    const r12 = Reg.fromVReg(v12);
    const wr8 = root.reg.WritableReg.fromReg(r8);

    // RBIT W8, W12
    try emit(.{ .rbit = .{
        .dst = wr8,
        .src = r12,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check fixed bits (bits 30-21) = 0b1011010110
    try testing.expectEqual(@as(u32, 0b1011010110), (insn >> 21) & 0x3FF);

    // Check opcode field (bits 10-15) = 0b00000
    try testing.expectEqual(@as(u32, 0b00000), (insn >> 10) & 0x3F);

    // Check Rn field (bits 5-9) = 12
    try testing.expectEqual(@as(u32, 12), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 8
    try testing.expectEqual(@as(u32, 8), insn & 0x1F);

    // Verify complete encoding: 0x5AC00188
    try testing.expectEqual(@as(u32, 0x5AC00188), insn);
}

test "emit bit manipulation with different registers" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // CLZ X0, X1
    try emit(.{ .clz = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    var insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check Rd = 0, Rn = 1
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);

    buffer.data.clearRetainingCapacity();

    // CLS X0, X1
    try emit(.{ .cls = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check Rd = 0, Rn = 1
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);

    buffer.data.clearRetainingCapacity();

    // RBIT X0, X1
    try emit(.{ .rbit = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check Rd = 0, Rn = 1
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
}

test "emit csel 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // CSEL X0, X1, X2, EQ
    try emit(.{ .csel = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .cond = .eq,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Encoding: sf|0|0|11010100|Rm|cond|00|Rn|Rd
    // sf=1, Rm=2, cond=0000 (EQ), op=00, Rn=1, Rd=0
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 for 64-bit
    try testing.expectEqual(@as(u32, 0b00011010100), (insn >> 20) & 0x7FF); // opcode
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b0000), (insn >> 12) & 0xF); // cond=EQ
    try testing.expectEqual(@as(u32, 0b00), (insn >> 10) & 0x3); // op=00 for CSEL
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // Rd
}

test "emit csel 32-bit with different conditions" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const v12 = root.reg.VReg.new(12, .int);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const r12 = Reg.fromVReg(v12);
    const wr10 = root.reg.WritableReg.fromReg(r10);

    // CSEL W10, W11, W12, GT (greater than)
    try emit(.{ .csel = .{
        .dst = wr10,
        .src1 = r11,
        .src2 = r12,
        .cond = .gt,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // sf=0, Rm=12, cond=1100 (GT), op=00, Rn=11, Rd=10
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 for 32-bit
    try testing.expectEqual(@as(u32, 12), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b1100), (insn >> 12) & 0xF); // cond=GT
    try testing.expectEqual(@as(u32, 0b00), (insn >> 10) & 0x3); // op=00
    try testing.expectEqual(@as(u32, 11), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 10), insn & 0x1F); // Rd
}

test "emit csinc 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // CSINC X3, X4, X5, NE
    try emit(.{ .csinc = .{
        .dst = wr3,
        .src1 = r4,
        .src2 = r5,
        .cond = .ne,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Encoding: sf|0|0|11010100|Rm|cond|01|Rn|Rd
    // sf=1, Rm=5, cond=0001 (NE), op=01, Rn=4, Rd=3
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1
    try testing.expectEqual(@as(u32, 0b00011010100), (insn >> 20) & 0x7FF); // opcode
    try testing.expectEqual(@as(u32, 5), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b0001), (insn >> 12) & 0xF); // cond=NE
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0x3); // op=01 for CSINC
    try testing.expectEqual(@as(u32, 4), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 3), insn & 0x1F); // Rd
}

test "emit csinc 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const v21 = root.reg.VReg.new(21, .int);
    const v22 = root.reg.VReg.new(22, .int);
    const r20 = Reg.fromVReg(v20);
    const r21 = Reg.fromVReg(v21);
    const r22 = Reg.fromVReg(v22);
    const wr20 = root.reg.WritableReg.fromReg(r20);

    // CSINC W20, W21, W22, HS (higher or same, unsigned >=)
    try emit(.{ .csinc = .{
        .dst = wr20,
        .src1 = r21,
        .src2 = r22,
        .cond = .hs,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // sf=0, Rm=22, cond=0010 (HS), op=01, Rn=21, Rd=20
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 for 32-bit
    try testing.expectEqual(@as(u32, 22), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b0010), (insn >> 12) & 0xF); // cond=HS
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0x3); // op=01
    try testing.expectEqual(@as(u32, 21), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 20), insn & 0x1F); // Rd
}

test "emit csinv 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);
    const wr6 = root.reg.WritableReg.fromReg(r6);

    // CSINV X6, X7, X8, LT (signed less than)
    try emit(.{ .csinv = .{
        .dst = wr6,
        .src1 = r7,
        .src2 = r8,
        .cond = .lt,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Encoding: sf|1|0|11010100|Rm|cond|00|Rn|Rd
    // sf=1, Rm=8, cond=1011 (LT), op=00 (but bit 30=1), Rn=7, Rd=6
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1
    try testing.expectEqual(@as(u32, 0b10011010100), (insn >> 20) & 0x7FF); // opcode with bit 30=1
    try testing.expectEqual(@as(u32, 8), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b1011), (insn >> 12) & 0xF); // cond=LT
    try testing.expectEqual(@as(u32, 0b00), (insn >> 10) & 0x3); // op=00
    try testing.expectEqual(@as(u32, 7), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 6), insn & 0x1F); // Rd
}

test "emit csinv 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v15 = root.reg.VReg.new(15, .int);
    const v16 = root.reg.VReg.new(16, .int);
    const v17 = root.reg.VReg.new(17, .int);
    const r15 = Reg.fromVReg(v15);
    const r16 = Reg.fromVReg(v16);
    const r17 = Reg.fromVReg(v17);
    const wr15 = root.reg.WritableReg.fromReg(r15);

    // CSINV W15, W16, W17, GE (signed >=)
    try emit(.{ .csinv = .{
        .dst = wr15,
        .src1 = r16,
        .src2 = r17,
        .cond = .ge,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // sf=0, Rm=17, cond=1010 (GE), op=00 (bit 30=1), Rn=16, Rd=15
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 for 32-bit
    try testing.expectEqual(@as(u32, 17), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b1010), (insn >> 12) & 0xF); // cond=GE
    try testing.expectEqual(@as(u32, 0b00), (insn >> 10) & 0x3); // op=00
    try testing.expectEqual(@as(u32, 16), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 15), insn & 0x1F); // Rd
}

test "emit csneg 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v9 = root.reg.VReg.new(9, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const r9 = Reg.fromVReg(v9);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const wr9 = root.reg.WritableReg.fromReg(r9);

    // CSNEG X9, X10, X11, LE (signed <=)
    try emit(.{ .csneg = .{
        .dst = wr9,
        .src1 = r10,
        .src2 = r11,
        .cond = .le,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Encoding: sf|1|0|11010100|Rm|cond|01|Rn|Rd
    // sf=1, Rm=11, cond=1101 (LE), op=01 (bit 30=1), Rn=10, Rd=9
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1
    try testing.expectEqual(@as(u32, 0b10011010100), (insn >> 20) & 0x7FF); // opcode with bit 30=1
    try testing.expectEqual(@as(u32, 11), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b1101), (insn >> 12) & 0xF); // cond=LE
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0x3); // op=01 for CSNEG
    try testing.expectEqual(@as(u32, 10), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 9), insn & 0x1F); // Rd
}

test "emit csneg 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v25 = root.reg.VReg.new(25, .int);
    const v26 = root.reg.VReg.new(26, .int);
    const v27 = root.reg.VReg.new(27, .int);
    const r25 = Reg.fromVReg(v25);
    const r26 = Reg.fromVReg(v26);
    const r27 = Reg.fromVReg(v27);
    const wr25 = root.reg.WritableReg.fromReg(r25);

    // CSNEG W25, W26, W27, HI (unsigned >)
    try emit(.{ .csneg = .{
        .dst = wr25,
        .src1 = r26,
        .src2 = r27,
        .cond = .hi,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // sf=0, Rm=27, cond=1000 (HI), op=01 (bit 30=1), Rn=26, Rd=25
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 for 32-bit
    try testing.expectEqual(@as(u32, 27), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b1000), (insn >> 12) & 0xF); // cond=HI
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0x3); // op=01
    try testing.expectEqual(@as(u32, 26), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 25), insn & 0x1F); // Rd
}

test "emit conditional select with same registers" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const r5 = Reg.fromVReg(v5);
    const wr5 = root.reg.WritableReg.fromReg(r5);

    // CSEL X5, X5, X5, AL (always)
    try emit(.{ .csel = .{
        .dst = wr5,
        .src1 = r5,
        .src2 = r5,
        .cond = .al,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // All registers should be 5
    try testing.expectEqual(@as(u32, 5), insn & 0x1F); // Rd
    try testing.expectEqual(@as(u32, 5), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 5), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b1110), (insn >> 12) & 0xF); // cond=AL
}
test "emit movz 64-bit shift 0" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // MOVZ X0, #0x1234, lsl #0
    try emit(.{ .movz = .{
        .dst = wr0,
        .imm = 0x1234,
        .shift = 0,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opc (bits 29-30) = 0b10 for MOVZ
    try testing.expectEqual(@as(u32, 0b10), (insn >> 29) & 0x3);

    // Check opcode (bits 23-28) = 0b100101
    try testing.expectEqual(@as(u32, 0b100101), (insn >> 23) & 0x3F);

    // Check hw (bits 21-22) = 0 for shift 0
    try testing.expectEqual(@as(u32, 0), (insn >> 21) & 0x3);

    // Check immediate value (bits 5-20) = 0x1234
    try testing.expectEqual(@as(u32, 0x1234), (insn >> 5) & 0xFFFF);

    // Check Rd = 0
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);

    // Verify complete encoding: 0xD2824680 (MOVZ X0, #0x1234)
    try testing.expectEqual(@as(u32, 0xD2824680), insn);
}

test "emit movz 64-bit shift 16" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const r5 = Reg.fromVReg(v5);
    const wr5 = root.reg.WritableReg.fromReg(r5);

    // MOVZ X5, #0xABCD, lsl #16
    try emit(.{ .movz = .{
        .dst = wr5,
        .imm = 0xABCD,
        .shift = 16,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check hw = 1 for shift 16
    try testing.expectEqual(@as(u32, 1), (insn >> 21) & 0x3);
    try testing.expectEqual(@as(u32, 0xABCD), (insn >> 5) & 0xFFFF);
    try testing.expectEqual(@as(u32, 5), insn & 0x1F);
}

test "emit movz 64-bit shift 32" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const r10 = Reg.fromVReg(v10);
    const wr10 = root.reg.WritableReg.fromReg(r10);

    // MOVZ X10, #0x5678, lsl #32
    try emit(.{ .movz = .{
        .dst = wr10,
        .imm = 0x5678,
        .shift = 32,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check hw = 2 for shift 32
    try testing.expectEqual(@as(u32, 2), (insn >> 21) & 0x3);
    try testing.expectEqual(@as(u32, 0x5678), (insn >> 5) & 0xFFFF);
    try testing.expectEqual(@as(u32, 10), insn & 0x1F);
}

test "emit movz 64-bit shift 48" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v15 = root.reg.VReg.new(15, .int);
    const r15 = Reg.fromVReg(v15);
    const wr15 = root.reg.WritableReg.fromReg(r15);

    // MOVZ X15, #0x1111, lsl #48
    try emit(.{ .movz = .{
        .dst = wr15,
        .imm = 0x1111,
        .shift = 48,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check hw = 3 for shift 48
    try testing.expectEqual(@as(u32, 3), (insn >> 21) & 0x3);
    try testing.expectEqual(@as(u32, 0x1111), (insn >> 5) & 0xFFFF);
    try testing.expectEqual(@as(u32, 15), insn & 0x1F);
}

test "emit movz 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const r20 = Reg.fromVReg(v20);
    const wr20 = root.reg.WritableReg.fromReg(r20);

    // MOVZ W20, #0x9999, lsl #0
    try emit(.{ .movz = .{
        .dst = wr20,
        .imm = 0x9999,
        .shift = 0,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);
    try testing.expectEqual(@as(u32, 0), (insn >> 21) & 0x3);
    try testing.expectEqual(@as(u32, 0x9999), (insn >> 5) & 0xFFFF);
    try testing.expectEqual(@as(u32, 20), insn & 0x1F);
}

test "emit movz 32-bit shift 16" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v7 = root.reg.VReg.new(7, .int);
    const r7 = Reg.fromVReg(v7);
    const wr7 = root.reg.WritableReg.fromReg(r7);

    // MOVZ W7, #0x4321, lsl #16
    try emit(.{ .movz = .{
        .dst = wr7,
        .imm = 0x4321,
        .shift = 16,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0, hw = 1
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);
    try testing.expectEqual(@as(u32, 1), (insn >> 21) & 0x3);
    try testing.expectEqual(@as(u32, 0x4321), (insn >> 5) & 0xFFFF);
    try testing.expectEqual(@as(u32, 7), insn & 0x1F);
}

test "emit movk 64-bit shift 0" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v1 = root.reg.VReg.new(1, .int);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    // MOVK X1, #0x5678, lsl #0
    try emit(.{ .movk = .{
        .dst = wr1,
        .imm = 0x5678,
        .shift = 0,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1, opc = 0b11 for MOVK
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);
    try testing.expectEqual(@as(u32, 0b11), (insn >> 29) & 0x3);
    try testing.expectEqual(@as(u32, 0b100101), (insn >> 23) & 0x3F);
    try testing.expectEqual(@as(u32, 0), (insn >> 21) & 0x3);
    try testing.expectEqual(@as(u32, 0x5678), (insn >> 5) & 0xFFFF);
    try testing.expectEqual(@as(u32, 1), insn & 0x1F);
}

test "emit movk 64-bit all shifts" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v2 = root.reg.VReg.new(2, .int);
    const r2 = Reg.fromVReg(v2);
    const wr2 = root.reg.WritableReg.fromReg(r2);

    // Test shift 16
    try emit(.{ .movk = .{ .dst = wr2, .imm = 0xFFFF, .shift = 16, .size = .size64 } }, &buffer);
    var insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 1), (insn >> 21) & 0x3);

    buffer.data.clearRetainingCapacity();

    // Test shift 32
    const v3 = root.reg.VReg.new(3, .int);
    const r3 = Reg.fromVReg(v3);
    const wr3 = root.reg.WritableReg.fromReg(r3);
    try emit(.{ .movk = .{ .dst = wr3, .imm = 0x1234, .shift = 32, .size = .size64 } }, &buffer);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 2), (insn >> 21) & 0x3);

    buffer.data.clearRetainingCapacity();

    // Test shift 48
    const v4 = root.reg.VReg.new(4, .int);
    const r4 = Reg.fromVReg(v4);
    const wr4 = root.reg.WritableReg.fromReg(r4);
    try emit(.{ .movk = .{ .dst = wr4, .imm = 0xABCD, .shift = 48, .size = .size64 } }, &buffer);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 3), (insn >> 21) & 0x3);
}

test "emit movk 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v25 = root.reg.VReg.new(25, .int);
    const r25 = Reg.fromVReg(v25);
    const wr25 = root.reg.WritableReg.fromReg(r25);

    // MOVK W25, #0x8888, lsl #0
    try emit(.{ .movk = .{ .dst = wr25, .imm = 0x8888, .shift = 0, .size = .size32 } }, &buffer);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);
    try testing.expectEqual(@as(u32, 0), (insn >> 21) & 0x3);

    buffer.data.clearRetainingCapacity();

    // Test shift 16
    const v30 = root.reg.VReg.new(30, .int);
    const r30 = Reg.fromVReg(v30);
    const wr30 = root.reg.WritableReg.fromReg(r30);
    try emit(.{ .movk = .{ .dst = wr30, .imm = 0x2222, .shift = 16, .size = .size32 } }, &buffer);
    const insn2 = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 1), (insn2 >> 21) & 0x3);
}

test "emit movn 64-bit all shifts" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v8 = root.reg.VReg.new(8, .int);
    const r8 = Reg.fromVReg(v8);
    const wr8 = root.reg.WritableReg.fromReg(r8);

    // Test shift 0
    try emit(.{ .movn = .{ .dst = wr8, .imm = 0x1234, .shift = 0, .size = .size64 } }, &buffer);
    var insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1
    try testing.expectEqual(@as(u32, 0b00), (insn >> 29) & 0x3); // opc=00 for MOVN
    try testing.expectEqual(@as(u32, 0), (insn >> 21) & 0x3); // hw=0

    buffer.data.clearRetainingCapacity();

    // Test shift 16, 32, 48
    const shifts = [_]u8{ 16, 32, 48 };
    const expected_hw = [_]u32{ 1, 2, 3 };
    const regs = [_]u8{ 9, 11, 12 };

    for (shifts, expected_hw, regs) |shift, hw, reg| {
        const v = root.reg.VReg.new(reg, .int);
        const r = Reg.fromVReg(v);
        const wr = root.reg.WritableReg.fromReg(r);
        try emit(.{ .movn = .{ .dst = wr, .imm = 0x5678, .shift = shift, .size = .size64 } }, &buffer);
        insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
        try testing.expectEqual(hw, (insn >> 21) & 0x3);
        buffer.data.clearRetainingCapacity();
    }
}

test "emit movn 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v13 = root.reg.VReg.new(13, .int);
    const r13 = Reg.fromVReg(v13);
    const wr13 = root.reg.WritableReg.fromReg(r13);

    // Test shift 0
    try emit(.{ .movn = .{ .dst = wr13, .imm = 0x7777, .shift = 0, .size = .size32 } }, &buffer);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0
    try testing.expectEqual(@as(u32, 0), (insn >> 21) & 0x3); // hw=0

    buffer.data.clearRetainingCapacity();

    // Test shift 16
    const v14 = root.reg.VReg.new(14, .int);
    const r14 = Reg.fromVReg(v14);
    const wr14 = root.reg.WritableReg.fromReg(r14);
    try emit(.{ .movn = .{ .dst = wr14, .imm = 0x1111, .shift = 16, .size = .size32 } }, &buffer);
    const insn2 = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 1), (insn2 >> 21) & 0x3); // hw=1
}

test "emit stp 64-bit zero offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    // STP X0, X1, [X2, #0]
    try emit(.{ .stp = .{
        .src1 = r0,
        .src2 = r1,
        .base = r2,
        .offset = 0,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding: sf|10|1|0|010|0|imm7|Rt2|Rn|Rt
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 (64-bit)
    try testing.expectEqual(@as(u32, 0b1010010), (insn >> 23) & 0x7F); // opc|V|mode
    try testing.expectEqual(@as(u32, 0), (insn >> 15) & 0x7F); // imm7=0
    try testing.expectEqual(@as(u32, 1), (insn >> 10) & 0x1F); // Rt2=X1
    try testing.expectEqual(@as(u32, 2), (insn >> 5) & 0x1F); // Rn=X2
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // Rt=X0
}

test "emit stp 64-bit positive offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const v12 = root.reg.VReg.new(12, .int);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const r12 = Reg.fromVReg(v12);

    // STP X10, X11, [X12, #16]
    // Offset 16 bytes = 2 * 8 bytes, so imm7 = 2
    try emit(.{ .stp = .{
        .src1 = r10,
        .src2 = r11,
        .base = r12,
        .offset = 16,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 (64-bit)
    try testing.expectEqual(@as(u32, 2), (insn >> 15) & 0x7F); // imm7=2 (16/8)
    try testing.expectEqual(@as(u32, 11), (insn >> 10) & 0x1F); // Rt2=X11
    try testing.expectEqual(@as(u32, 12), (insn >> 5) & 0x1F); // Rn=X12
    try testing.expectEqual(@as(u32, 10), insn & 0x1F); // Rt=X10
}

test "emit stp 64-bit negative offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const v21 = root.reg.VReg.new(21, .int);
    const v22 = root.reg.VReg.new(22, .int);
    const r20 = Reg.fromVReg(v20);
    const r21 = Reg.fromVReg(v21);
    const r22 = Reg.fromVReg(v22);

    // STP X20, X21, [X22, #-16]
    // Offset -16 bytes = -2 * 8 bytes, so imm7 = -2 (0x7E in 7-bit two's complement)
    try emit(.{ .stp = .{
        .src1 = r20,
        .src2 = r21,
        .base = r22,
        .offset = -16,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 (64-bit)
    try testing.expectEqual(@as(u32, 0x7E), (insn >> 15) & 0x7F); // imm7=-2
    try testing.expectEqual(@as(u32, 21), (insn >> 10) & 0x1F); // Rt2=X21
    try testing.expectEqual(@as(u32, 22), (insn >> 5) & 0x1F); // Rn=X22
    try testing.expectEqual(@as(u32, 20), insn & 0x1F); // Rt=X20
}

test "emit stp 32-bit zero offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);

    // STP W3, W4, [X5, #0]
    try emit(.{ .stp = .{
        .src1 = r3,
        .src2 = r4,
        .base = r5,
        .offset = 0,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding: sf|10|1|0|010|0|imm7|Rt2|Rn|Rt
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 (32-bit)
    try testing.expectEqual(@as(u32, 0b1010010), (insn >> 23) & 0x7F); // opc|V|mode
    try testing.expectEqual(@as(u32, 0), (insn >> 15) & 0x7F); // imm7=0
    try testing.expectEqual(@as(u32, 4), (insn >> 10) & 0x1F); // Rt2=W4
    try testing.expectEqual(@as(u32, 5), (insn >> 5) & 0x1F); // Rn=X5
    try testing.expectEqual(@as(u32, 3), insn & 0x1F); // Rt=W3
}

test "emit stp 32-bit with offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);

    // STP W6, W7, [X8, #8]
    // For 32-bit, offset is scaled by 4, so 8 bytes = imm7 of 2
    try emit(.{ .stp = .{
        .src1 = r6,
        .src2 = r7,
        .base = r8,
        .offset = 8,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 (32-bit)
    // For 32-bit, offset is divided by 4 (size of 32-bit register pair element)
    try testing.expectEqual(@as(u32, 2), (insn >> 15) & 0x7F); // imm7=2 (8/4)
    try testing.expectEqual(@as(u32, 7), (insn >> 10) & 0x1F); // Rt2=W7
    try testing.expectEqual(@as(u32, 8), (insn >> 5) & 0x1F); // Rn=X8
    try testing.expectEqual(@as(u32, 6), insn & 0x1F); // Rt=W6
}

test "emit ldp 64-bit zero offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    // LDP X0, X1, [X2, #0]
    try emit(.{ .ldp = .{
        .dst1 = wr0,
        .dst2 = wr1,
        .base = r2,
        .offset = 0,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding: sf|10|1|0|011|0|imm7|Rt2|Rn|Rt
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 (64-bit)
    try testing.expectEqual(@as(u32, 0b1010011), (insn >> 23) & 0x7F); // opc|V|mode (note: bit 22 is 1 for LDP)
    try testing.expectEqual(@as(u32, 0), (insn >> 15) & 0x7F); // imm7=0
    try testing.expectEqual(@as(u32, 1), (insn >> 10) & 0x1F); // Rt2=X1
    try testing.expectEqual(@as(u32, 2), (insn >> 5) & 0x1F); // Rn=X2
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // Rt=X0
}

test "emit ldp 64-bit positive offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const v12 = root.reg.VReg.new(12, .int);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const r12 = Reg.fromVReg(v12);
    const wr10 = root.reg.WritableReg.fromReg(r10);
    const wr11 = root.reg.WritableReg.fromReg(r11);

    // LDP X10, X11, [X12, #32]
    // Offset 32 bytes = 4 * 8 bytes, so imm7 = 4
    try emit(.{ .ldp = .{
        .dst1 = wr10,
        .dst2 = wr11,
        .base = r12,
        .offset = 32,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 (64-bit)
    try testing.expectEqual(@as(u32, 4), (insn >> 15) & 0x7F); // imm7=4 (32/8)
    try testing.expectEqual(@as(u32, 11), (insn >> 10) & 0x1F); // Rt2=X11
    try testing.expectEqual(@as(u32, 12), (insn >> 5) & 0x1F); // Rn=X12
    try testing.expectEqual(@as(u32, 10), insn & 0x1F); // Rt=X10
}

test "emit ldp 64-bit negative offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const v21 = root.reg.VReg.new(21, .int);
    const v22 = root.reg.VReg.new(22, .int);
    const r20 = Reg.fromVReg(v20);
    const r21 = Reg.fromVReg(v21);
    const r22 = Reg.fromVReg(v22);
    const wr20 = root.reg.WritableReg.fromReg(r20);
    const wr21 = root.reg.WritableReg.fromReg(r21);

    // LDP X20, X21, [X22, #-24]
    // Offset -24 bytes = -3 * 8 bytes, so imm7 = -3 (0x7D in 7-bit two's complement)
    try emit(.{ .ldp = .{
        .dst1 = wr20,
        .dst2 = wr21,
        .base = r22,
        .offset = -24,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 (64-bit)
    try testing.expectEqual(@as(u32, 0x7D), (insn >> 15) & 0x7F); // imm7=-3
    try testing.expectEqual(@as(u32, 21), (insn >> 10) & 0x1F); // Rt2=X21
    try testing.expectEqual(@as(u32, 22), (insn >> 5) & 0x1F); // Rn=X22
    try testing.expectEqual(@as(u32, 20), insn & 0x1F); // Rt=X20
}

test "emit ldp 32-bit zero offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);
    const wr4 = root.reg.WritableReg.fromReg(r4);

    // LDP W3, W4, [X5, #0]
    try emit(.{ .ldp = .{
        .dst1 = wr3,
        .dst2 = wr4,
        .base = r5,
        .offset = 0,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 (32-bit)
    try testing.expectEqual(@as(u32, 0b1010011), (insn >> 23) & 0x7F); // opc|V|mode
    try testing.expectEqual(@as(u32, 0), (insn >> 15) & 0x7F); // imm7=0
    try testing.expectEqual(@as(u32, 4), (insn >> 10) & 0x1F); // Rt2=W4
    try testing.expectEqual(@as(u32, 5), (insn >> 5) & 0x1F); // Rn=X5
    try testing.expectEqual(@as(u32, 3), insn & 0x1F); // Rt=W3
}

test "emit ldp 32-bit with offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);
    const wr6 = root.reg.WritableReg.fromReg(r6);
    const wr7 = root.reg.WritableReg.fromReg(r7);

    // LDP W6, W7, [X8, #16]
    // For 32-bit, offset is scaled by 4, so 16 bytes = imm7 of 4
    try emit(.{ .ldp = .{
        .dst1 = wr6,
        .dst2 = wr7,
        .base = r8,
        .offset = 16,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 (32-bit)
    // For 32-bit, offset is divided by 4 (size of 32-bit register pair element)
    try testing.expectEqual(@as(u32, 4), (insn >> 15) & 0x7F); // imm7=4 (16/4)
    try testing.expectEqual(@as(u32, 7), (insn >> 10) & 0x1F); // Rt2=W7
    try testing.expectEqual(@as(u32, 8), (insn >> 5) & 0x1F); // Rn=X8
    try testing.expectEqual(@as(u32, 6), insn & 0x1F); // Rt=W6
}

test "emit ldp and stp with max positive offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    // Max positive offset for 7-bit signed: 63 * 8 = 504 bytes
    try emit(.{ .stp = .{
        .src1 = r0,
        .src2 = r1,
        .base = r2,
        .offset = 504,
        .size = .size64,
    } }, &buffer);

    const insn1 = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 63), (insn1 >> 15) & 0x7F); // imm7=63

    buffer.data.clearRetainingCapacity();

    // Test LDP with same offset
    try emit(.{ .ldp = .{
        .dst1 = wr0,
        .dst2 = wr1,
        .base = r2,
        .offset = 504,
        .size = .size64,
    } }, &buffer);

    const insn2 = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 63), (insn2 >> 15) & 0x7F); // imm7=63
}

test "emit ldp and stp with max negative offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    // Max negative offset for 7-bit signed: -64 * 8 = -512 bytes
    try emit(.{ .stp = .{
        .src1 = r0,
        .src2 = r1,
        .base = r2,
        .offset = -512,
        .size = .size64,
    } }, &buffer);

    const insn1 = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x40), (insn1 >> 15) & 0x7F); // imm7=-64 (0x40 in 7-bit)

    buffer.data.clearRetainingCapacity();

    // Test LDP with same offset
    try emit(.{ .ldp = .{
        .dst1 = wr0,
        .dst2 = wr1,
        .base = r2,
        .offset = -512,
        .size = .size64,
    } }, &buffer);

    const insn2 = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x40), (insn2 >> 15) & 0x7F); // imm7=-64
}

test "emit br" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const r5 = Reg.fromVReg(v5);

    // BR X5
    try emit(.{ .br = .{ .target = r5 } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Expected encoding: 0xd61f00a0 for BR X5
    try testing.expectEqual(@as(u32, 0xd61f00a0), insn);

    // Verify bit fields
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F); // op bits
    try testing.expectEqual(@as(u32, 0b00), (insn >> 21) & 0x3); // opc for BR
    try testing.expectEqual(@as(u32, 5), (insn >> 5) & 0x1F); // Rn=X5
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // Rm=0
}

test "emit br multiple registers" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Test BR with different registers
    const registers = [_]u5{ 0, 1, 10, 15, 30 };
    for (registers) |reg_idx| {
        buffer.data.clearRetainingCapacity();

        const vreg = root.reg.VReg.new(reg_idx, .int);
        const reg = Reg.fromVReg(vreg);

        try emit(.{ .br = .{ .target = reg } }, &buffer);

        try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
        const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

        // Verify register encoding
        try testing.expectEqual(@as(u32, reg_idx), (insn >> 5) & 0x1F);
        // Verify opcode
        try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F);
        try testing.expectEqual(@as(u32, 0b00), (insn >> 21) & 0x3);
    }
}

test "emit blr" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const r5 = Reg.fromVReg(v5);

    // BLR X5
    try emit(.{ .blr = .{ .target = r5 } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Expected encoding: 0xd63f00a0 for BLR X5
    try testing.expectEqual(@as(u32, 0xd63f00a0), insn);

    // Verify bit fields
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F); // op bits
    try testing.expectEqual(@as(u32, 0b01), (insn >> 21) & 0x3); // opc for BLR
    try testing.expectEqual(@as(u32, 5), (insn >> 5) & 0x1F); // Rn=X5
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // Rm=0
}

test "emit blr multiple registers" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Test BLR with different registers
    const registers = [_]u5{ 0, 1, 10, 15, 30 };
    for (registers) |reg_idx| {
        buffer.data.clearRetainingCapacity();

        const vreg = root.reg.VReg.new(reg_idx, .int);
        const reg = Reg.fromVReg(vreg);

        try emit(.{ .blr = .{ .target = reg } }, &buffer);

        try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
        const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

        // Verify register encoding
        try testing.expectEqual(@as(u32, reg_idx), (insn >> 5) & 0x1F);
        // Verify opcode
        try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F);
        try testing.expectEqual(@as(u32, 0b01), (insn >> 21) & 0x3);
    }
}

test "emit bl indirect via CallTarget" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const r10 = Reg.fromVReg(v10);

    // BL with indirect target (should emit BLR)
    const target = root.aarch64_inst.CallTarget{ .indirect = r10 };
    try emit(.{ .bl = .{ .target = target } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Should emit BLR X10: 0xd63f0140
    try testing.expectEqual(@as(u32, 0xd63f0140), insn);

    // Verify it's BLR encoding
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F);
    try testing.expectEqual(@as(u32, 0b01), (insn >> 21) & 0x3); // BLR opcode
    try testing.expectEqual(@as(u32, 10), (insn >> 5) & 0x1F); // Rn=X10
}

test "emit ret with default register" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // RET (defaults to X30)
    try emit(.{ .ret = .{ .reg = null } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Expected encoding: 0xd65f03c0 for RET (X30)
    try testing.expectEqual(@as(u32, 0xd65f03c0), insn);

    // Verify bit fields
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F);
    try testing.expectEqual(@as(u32, 0b10), (insn >> 21) & 0x3); // opc for RET
    try testing.expectEqual(@as(u32, 30), (insn >> 5) & 0x1F); // Rn=X30
}

test "emit ret with explicit register" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v15 = root.reg.VReg.new(15, .int);
    const r15 = Reg.fromVReg(v15);

    // RET X15
    try emit(.{ .ret = .{ .reg = r15 } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify bit fields
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F);
    try testing.expectEqual(@as(u32, 0b10), (insn >> 21) & 0x3); // opc for RET
    try testing.expectEqual(@as(u32, 15), (insn >> 5) & 0x1F); // Rn=X15
}

test "cmp is alias for subs with xzr" {
    // Verify that CMP produces the exact same encoding as SUBS with XZR destination
    var buffer1 = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer1.deinit();
    var buffer2 = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer2.deinit();

    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    // Emit CMP X1, X2
    try emit(.{ .cmp_rr = .{
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer1);

    // Emit SUBS XZR, X1, X2
    const xzr = Reg.fromPReg(root.reg.PReg.xzr);
    const wxzr = root.reg.WritableReg.fromReg(xzr);
    try emit(.{ .subs_rr = .{
        .dst = wxzr,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer2);

    // Both should produce identical encodings
    try testing.expectEqual(@as(usize, 4), buffer1.data.items.len);
    try testing.expectEqual(@as(usize, 4), buffer2.data.items.len);
    const insn1 = std.mem.bytesToValue(u32, buffer1.data.items[0..4]);
    const insn2 = std.mem.bytesToValue(u32, buffer2.data.items[0..4]);
    try testing.expectEqual(insn1, insn2);
}

test "emit ldr_reg 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LDR X0, [X1, X2]
    try emit(.{ .ldr_reg = .{
        .dst = wr0,
        .base = r1,
        .offset = r2,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf|111|0|00|01|Rm|011|0|10|Rn|Rt
    // sf=1, Rm=2, option=011, S=0, Rn=1, Rt=0
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100001 << 21) | (2 << 16) | (0b011010 << 10) | (1 << 5) | 0;
    try testing.expectEqual(expected, insn);
}

test "emit ldr_reg 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v15 = root.reg.VReg.new(15, .int);
    const r5 = Reg.fromVReg(v5);
    const r10 = Reg.fromVReg(v10);
    const r15 = Reg.fromVReg(v15);
    const wr5 = root.reg.WritableReg.fromReg(r5);

    // LDR W5, [X10, X15]
    try emit(.{ .ldr_reg = .{
        .dst = wr5,
        .base = r10,
        .offset = r15,
        .size = .size32,
    } }, &buffer);

    // Verify encoding: sf=0, Rm=15, option=011, S=0, Rn=10, Rt=5
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (0 << 31) | (0b11100001 << 21) | (15 << 16) | (0b011010 << 10) | (10 << 5) | 5;
    try testing.expectEqual(expected, insn);
}

test "emit ldr_ext sxtw 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LDR X0, [X1, W2, SXTW]
    try emit(.{ .ldr_ext = .{
        .dst = wr0,
        .base = r1,
        .offset = r2,
        .extend = .sxtw,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=2, option=110 (SXTW), S=0, Rn=1, Rt=0
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100001 << 21) | (2 << 16) | (0b110 << 13) | (0b010 << 10) | (1 << 5) | 0;
    try testing.expectEqual(expected, insn);
}

test "emit ldr_ext uxtw 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // LDR X3, [X4, W5, UXTW]
    try emit(.{ .ldr_ext = .{
        .dst = wr3,
        .base = r4,
        .offset = r5,
        .extend = .uxtw,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=5, option=010 (UXTW), S=0, Rn=4, Rt=3
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100001 << 21) | (5 << 16) | (0b010 << 13) | (0b010 << 10) | (4 << 5) | 3;
    try testing.expectEqual(expected, insn);
}

test "emit ldr_scaled 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LDR X0, [X1, X2, LSL #3]
    try emit(.{ .ldr_scaled = .{
        .dst = wr0,
        .base = r1,
        .offset = r2,
        .shift = 3,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=2, option=011, S=1 (scaled), Rn=1, Rt=0
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100001 << 21) | (2 << 16) | (0b011 << 13) | (1 << 12) | (0b10 << 10) | (1 << 5) | 0;
    try testing.expectEqual(expected, insn);
}

test "emit ldr_scaled 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);
    const wr6 = root.reg.WritableReg.fromReg(r6);

    // LDR W6, [X7, X8, LSL #2]
    try emit(.{ .ldr_scaled = .{
        .dst = wr6,
        .base = r7,
        .offset = r8,
        .shift = 2,
        .size = .size32,
    } }, &buffer);

    // Verify encoding: sf=0, Rm=8, option=011, S=1 (scaled), Rn=7, Rt=6
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (0 << 31) | (0b11100001 << 21) | (8 << 16) | (0b011 << 13) | (1 << 12) | (0b10 << 10) | (7 << 5) | 6;
    try testing.expectEqual(expected, insn);
}

test "emit str_reg 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    // STR X0, [X1, X2]
    try emit(.{ .str_reg = .{
        .src = r0,
        .base = r1,
        .offset = r2,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf|111|0|00|00|Rm|011|0|10|Rn|Rt
    // sf=1, Rm=2, option=011, S=0, Rn=1, Rt=0
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100000 << 21) | (2 << 16) | (0b011010 << 10) | (1 << 5) | 0;
    try testing.expectEqual(expected, insn);
}

test "emit str_reg 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v20 = root.reg.VReg.new(20, .int);
    const v30 = root.reg.VReg.new(30, .int);
    const r10 = Reg.fromVReg(v10);
    const r20 = Reg.fromVReg(v20);
    const r30 = Reg.fromVReg(v30);

    // STR W10, [X20, X30]
    try emit(.{ .str_reg = .{
        .src = r10,
        .base = r20,
        .offset = r30,
        .size = .size32,
    } }, &buffer);

    // Verify encoding: sf=0, Rm=30, option=011, S=0, Rn=20, Rt=10
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (0 << 31) | (0b11100000 << 21) | (30 << 16) | (0b011010 << 10) | (20 << 5) | 10;
    try testing.expectEqual(expected, insn);
}

test "emit str_ext sxtw 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);

    // STR X3, [X4, W5, SXTW]
    try emit(.{ .str_ext = .{
        .src = r3,
        .base = r4,
        .offset = r5,
        .extend = .sxtw,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=5, option=110 (SXTW), S=0, Rn=4, Rt=3
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100000 << 21) | (5 << 16) | (0b110 << 13) | (0b010 << 10) | (4 << 5) | 3;
    try testing.expectEqual(expected, insn);
}

test "emit str_ext uxtw 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);

    // STR X6, [X7, W8, UXTW]
    try emit(.{ .str_ext = .{
        .src = r6,
        .base = r7,
        .offset = r8,
        .extend = .uxtw,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=8, option=010 (UXTW), S=0, Rn=7, Rt=6
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100000 << 21) | (8 << 16) | (0b010 << 13) | (0b010 << 10) | (7 << 5) | 6;
    try testing.expectEqual(expected, insn);
}

test "emit str_scaled 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v9 = root.reg.VReg.new(9, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const r9 = Reg.fromVReg(v9);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);

    // STR X9, [X10, X11, LSL #3]
    try emit(.{ .str_scaled = .{
        .src = r9,
        .base = r10,
        .offset = r11,
        .shift = 3,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=11, option=011, S=1 (scaled), Rn=10, Rt=9
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100000 << 21) | (11 << 16) | (0b011 << 13) | (1 << 12) | (0b10 << 10) | (10 << 5) | 9;
    try testing.expectEqual(expected, insn);
}

test "emit str_scaled 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v12 = root.reg.VReg.new(12, .int);
    const v13 = root.reg.VReg.new(13, .int);
    const v14 = root.reg.VReg.new(14, .int);
    const r12 = Reg.fromVReg(v12);
    const r13 = Reg.fromVReg(v13);
    const r14 = Reg.fromVReg(v14);

    // STR W12, [X13, X14, LSL #2]
    try emit(.{ .str_scaled = .{
        .src = r12,
        .base = r13,
        .offset = r14,
        .shift = 2,
        .size = .size32,
    } }, &buffer);

    // Verify encoding: sf=0, Rm=14, option=011, S=1 (scaled), Rn=13, Rt=12
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (0 << 31) | (0b11100000 << 21) | (14 << 16) | (0b011 << 13) | (1 << 12) | (0b10 << 10) | (13 << 5) | 12;
    try testing.expectEqual(expected, insn);
}

test "emit ldr/str all extend modes" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // Test all extend types
    const extend_types = [_]Inst.ExtendOp{ .uxtb, .uxth, .uxtw, .uxtx, .sxtb, .sxth, .sxtw, .sxtx };

    for (extend_types) |ext| {
        buffer.data.clearRetainingCapacity();

        try emit(.{ .ldr_ext = .{
            .dst = wr0,
            .base = r1,
            .offset = r2,
            .extend = ext,
            .size = .size64,
        } }, &buffer);

        try testing.expectEqual(@as(usize, 4), buffer.data.items.len);

        buffer.data.clearRetainingCapacity();

        try emit(.{ .str_ext = .{
            .src = r0,
            .base = r1,
            .offset = r2,
            .extend = ext,
            .size = .size64,
        } }, &buffer);

        try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    }
}

test "cmn is alias for adds with xzr" {
    // Verify that CMN produces the exact same encoding as ADDS with XZR destination
    var buffer1 = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer1.deinit();
    var buffer2 = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer2.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);

    // Emit CMN X3, X4
    try emit(.{ .cmn_rr = .{
        .src1 = r3,
        .src2 = r4,
        .size = .size64,
    } }, &buffer1);

    // Emit ADDS XZR, X3, X4
    const xzr = Reg.fromPReg(root.reg.PReg.xzr);
    const wxzr = root.reg.WritableReg.fromReg(xzr);
    try emit(.{ .adds_rr = .{
        .dst = wxzr,
        .src1 = r3,
        .src2 = r4,
        .size = .size64,
    } }, &buffer2);

    // Both should produce identical encodings
    try testing.expectEqual(@as(usize, 4), buffer1.data.items.len);
    try testing.expectEqual(@as(usize, 4), buffer2.data.items.len);
    const insn1 = std.mem.bytesToValue(u32, buffer1.data.items[0..4]);
    const insn2 = std.mem.bytesToValue(u32, buffer2.data.items[0..4]);
    try testing.expectEqual(insn1, insn2);
}
