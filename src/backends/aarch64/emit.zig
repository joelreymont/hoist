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
        .ldr => |i| try emitLdr(i.dst.toReg(), i.base, i.offset, i.size, buffer),
        .str => |i| try emitStr(i.src, i.base, i.offset, i.size, buffer),
        .stp => |i| try emitStp(i.src1, i.src2, i.base, i.offset, i.size, buffer),
        .ldp => |i| try emitLdp(i.dst1.toReg(), i.dst2.toReg(), i.base, i.offset, i.size, buffer),
        .b => |i| try emitB(i.target.label, buffer),
        .b_cond => |i| try emitBCond(@intFromEnum(i.cond), i.target.label, buffer),
        .bl => try emitBL(0, buffer), // Stub - needs label
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

/// STP Xt1, Xt2, [Xn, #offset]
fn emitStp(src1: Reg, src2: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src1);
    const rt2 = hwEnc(src2);
    const rn = hwEnc(base);
    const imm7: u7 = @truncate(@as(u16, @bitCast(offset)) >> 3); // Scaled offset

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
    const imm7: u7 = @truncate(@as(u16, @bitCast(offset)) >> 3);

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
