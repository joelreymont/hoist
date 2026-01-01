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
