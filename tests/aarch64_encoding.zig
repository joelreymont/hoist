const std = @import("std");
const testing = std.testing;
const emit = @import("../src/backends/aarch64/emit.zig");
const Reg = @import("../src/machinst/reg.zig").Reg;
const PReg = @import("../src/machinst/reg.zig").PReg;
const WritableReg = @import("../src/machinst/reg.zig").WritableReg;
const RegClass = @import("../src/machinst/reg.zig").RegClass;
const OperandSize = @import("../src/backends/aarch64/inst.zig").OperandSize;
const MachBuffer = @import("../src/machinst/buffer.zig").MachBuffer;

// Test MOVZ encoding against ARM Architecture Reference Manual
// MOVZ Wd, #imm: sf|10|100101|hw|imm16|Rd
test "encoding: MOVZ w0, #42" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    // movz w0, #42
    const w0_preg = PReg.new(RegClass.int, 0);
    const w0 = Reg.fromPReg(w0_preg);
    const dst = WritableReg.fromReg(w0);

    try emit.emitMovImm(dst.toReg(), 42, .size32, &buffer);

    // Expected encoding: sf=0, opc=10, hw=00, imm16=42, Rd=0
    // Binary: 0|10|100101|00|0000000000101010|00000
    // Hex: 0x52800540 (little-endian: 40 05 80 52)
    const expected = [_]u8{ 0x40, 0x05, 0x80, 0x52 };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test MOVZ with different immediate values
test "encoding: MOVZ w1, #123" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const w1_preg = PReg.new(RegClass.int, 1);
    const w1 = Reg.fromPReg(w1_preg);
    const dst = WritableReg.fromReg(w1);

    try emit.emitMovImm(dst.toReg(), 123, .size32, &buffer);

    // Expected: sf=0, opc=10, hw=00, imm16=123 (0x7B), Rd=1
    // Binary: 0|10|100101|00|0000000001111011|00001
    // Hex: 0x52800F61 (little-endian: 61 0f 80 52)
    const expected = [_]u8{ 0x61, 0x0f, 0x80, 0x52 };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test MOVZ 64-bit variant
test "encoding: MOVZ x0, #42" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const x0_preg = PReg.new(RegClass.int, 0);
    const x0 = Reg.fromPReg(x0_preg);
    const dst = WritableReg.fromReg(x0);

    try emit.emitMovImm(dst.toReg(), 42, .size64, &buffer);

    // Expected: sf=1, opc=10, hw=00, imm16=42, Rd=0
    // Binary: 1|10|100101|00|0000000000101010|00000
    // Hex: 0xD2800540 (little-endian: 40 05 80 d2)
    const expected = [_]u8{ 0x40, 0x05, 0x80, 0xd2 };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test ORR (MOV register) encoding
// ORR Wd, WZR, Wm: sf|opc|01010|shift|N|Rm|imm6|Rn|Rd
test "encoding: ORR w0, wzr, w1 (MOV w0, w1)" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    // mov w0, w1 (implemented as orr w0, wzr, w1)
    const w0_preg = PReg.new(RegClass.int, 0);
    const w0 = Reg.fromPReg(w0_preg);
    const dst = WritableReg.fromReg(w0);

    const w1_preg = PReg.new(RegClass.int, 1);
    const w1 = Reg.fromPReg(w1_preg);

    try emit.emitMovRR(dst.toReg(), w1, .size32, &buffer);

    // Expected: sf=0, opc=01, fixed=01010, shift=00, N=0, Rm=1, imm6=0, Rn=31, Rd=0
    // Binary: 0|01|01010|00|0|00001|000000|11111|00000
    // Hex: 0x2A0103E0 (little-endian: e0 03 01 2a)
    const expected = [_]u8{ 0xe0, 0x03, 0x01, 0x2a };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test ORR with different registers
test "encoding: ORR w2, wzr, w3 (MOV w2, w3)" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const w2_preg = PReg.new(RegClass.int, 2);
    const w2 = Reg.fromPReg(w2_preg);
    const dst = WritableReg.fromReg(w2);

    const w3_preg = PReg.new(RegClass.int, 3);
    const w3 = Reg.fromPReg(w3_preg);

    try emit.emitMovRR(dst.toReg(), w3, .size32, &buffer);

    // Expected: sf=0, opc=01, fixed=01010, shift=00, N=0, Rm=3, imm6=0, Rn=31, Rd=2
    // Binary: 0|01|01010|00|0|00011|000000|11111|00010
    // Hex: 0x2A0303E2 (little-endian: e2 03 03 2a)
    const expected = [_]u8{ 0xe2, 0x03, 0x03, 0x2a };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test ORR 64-bit variant
test "encoding: ORR x0, xzr, x1 (MOV x0, x1)" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const x0_preg = PReg.new(RegClass.int, 0);
    const x0 = Reg.fromPReg(x0_preg);
    const dst = WritableReg.fromReg(x0);

    const x1_preg = PReg.new(RegClass.int, 1);
    const x1 = Reg.fromPReg(x1_preg);

    try emit.emitMovRR(dst.toReg(), x1, .size64, &buffer);

    // Expected: sf=1, opc=01, fixed=01010, shift=00, N=0, Rm=1, imm6=0, Rn=31, Rd=0
    // Binary: 1|01|01010|00|0|00001|000000|11111|00000
    // Hex: 0xAA0103E0 (little-endian: e0 03 01 aa)
    const expected = [_]u8{ 0xe0, 0x03, 0x01, 0xaa };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test ADD (shifted register) encoding
// ADD Wd, Wn, Wm: sf|0|0|01011|shift|0|Rm|imm6|Rn|Rd
test "encoding: ADD w0, w1, w2" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const w0_preg = PReg.new(RegClass.int, 0);
    const w0 = Reg.fromPReg(w0_preg);
    const dst = WritableReg.fromReg(w0);

    const w1_preg = PReg.new(RegClass.int, 1);
    const w1 = Reg.fromPReg(w1_preg);

    const w2_preg = PReg.new(RegClass.int, 2);
    const w2 = Reg.fromPReg(w2_preg);

    try emit.emitAddRR(dst.toReg(), w1, w2, .size32, &buffer);

    // Expected: sf=0, op=0, S=0, shift=00, Rm=2, imm6=0, Rn=1, Rd=0
    // Binary: 0|0|0|01011|00|0|00010|000000|00001|00000
    // Hex: 0x0B020020 (little-endian: 20 00 02 0b)
    const expected = [_]u8{ 0x20, 0x00, 0x02, 0x0b };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test MUL encoding
// MADD Wd, Wn, Wm, WZR: sf|0|0|11011|000|Rm|0|Ra|Rn|Rd (Ra=31 for MUL)
test "encoding: MUL w0, w1, w2 (MADD w0, w1, w2, wzr)" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const w0_preg = PReg.new(RegClass.int, 0);
    const w0 = Reg.fromPReg(w0_preg);
    const dst = WritableReg.fromReg(w0);

    const w1_preg = PReg.new(RegClass.int, 1);
    const w1 = Reg.fromPReg(w1_preg);

    const w2_preg = PReg.new(RegClass.int, 2);
    const w2 = Reg.fromPReg(w2_preg);

    try emit.emitMulRR(dst.toReg(), w1, w2, .size32, &buffer);

    // Expected: sf=0, op54=00, fixed=11011, op31=000, Rm=2, o0=0, Ra=31, Rn=1, Rd=0
    // Binary: 0|00|11011|000|00010|0|11111|00001|00000
    // Hex: 0x1B027C20 (little-endian: 20 7c 02 1b)
    const expected = [_]u8{ 0x20, 0x7c, 0x02, 0x1b };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test RET encoding
// RET: 1101011|0|0|10|11111|0000|0|0|Rn|00000 (Rn=30 for X30/LR)
test "encoding: RET" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    try emit.emitRet(null, &buffer);

    // Expected: fixed bits with Rn=30 (X30/LR)
    // Binary: 1101011|0|0|10|11111|0000|0|0|11110|00000
    // Hex: 0xD65F03C0 (little-endian: c0 03 5f d6)
    const expected = [_]u8{ 0xc0, 0x03, 0x5f, 0xd6 };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}
// Test CINC encoding (Conditional Increment)
// CINC is alias for CSINC with Rm==Rn and inverted condition
// CSINC: sf|0|0|11010100|Rm|cond|01|Rn|Rd
// CINC Xd, Xn, cond => CSINC Xd, Xn, Xn, invert(cond)
test "encoding: CINC x0, x1, EQ" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const CondCode = @import("../src/backends/aarch64/inst.zig").CondCode;
    const x0_preg = PReg.new(RegClass.int, 0);
    const x1_preg = PReg.new(RegClass.int, 1);
    const x0 = Reg.fromPReg(x0_preg);
    const x1 = Reg.fromPReg(x1_preg);
    const dst = WritableReg.fromReg(x0);

    try emit.emitCinc(dst.toReg(), x1, CondCode.eq, .size64, &buffer);

    // CINC with EQ (0x0) => CSINC with NE (0x1)
    // Expected: sf=1, opc=00, Rm=1, cond=1 (NE), op2=01, Rn=1, Rd=0
    // Binary: 1|0|0|11010100|00001|0001|01|00001|00000
    // Hex: 0x9A810420 (little-endian: 20 04 81 9a)
    const expected = [_]u8{ 0x20, 0x04, 0x81, 0x9a };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test CINC with 32-bit operands
test "encoding: CINC w2, w3, LT" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const CondCode = @import("../src/backends/aarch64/inst.zig").CondCode;
    const w2_preg = PReg.new(RegClass.int, 2);
    const w3_preg = PReg.new(RegClass.int, 3);
    const w2 = Reg.fromPReg(w2_preg);
    const w3 = Reg.fromPReg(w3_preg);
    const dst = WritableReg.fromReg(w2);

    try emit.emitCinc(dst.toReg(), w3, CondCode.lt, .size32, &buffer);

    // CINC with LT (0xB) => CSINC with GE (0xA)
    // Expected: sf=0, opc=00, Rm=3, cond=A (GE), op2=01, Rn=3, Rd=2
    // Binary: 0|0|0|11010100|00011|1010|01|00011|00010
    // Hex: 0x1A83A462 (little-endian: 62 a4 83 1a)
    const expected = [_]u8{ 0x62, 0xa4, 0x83, 0x1a };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test TBZ encoding (Test Bit and Branch if Zero)
// TBZ: b5|011011|0|b40|imm14|Rt
// Tests bit N of register Rt and branches if zero
test "encoding: TBZ x0, #5, label" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const x0_preg = PReg.new(RegClass.int, 0);
    const x0 = Reg.fromPReg(x0_preg);

    // TBZ x0, #5, +8 (skip 2 instructions)
    try emit.emitTbz(x0, 5, 2, &buffer);

    // Expected: b5=0, op=011011, o=0, b40=5, imm14=2, Rt=0
    // Binary: 0|011011|0|00101|00000000000010|00000
    // Hex: 0x36280040 (little-endian: 40 00 28 36)
    const expected = [_]u8{ 0x40, 0x00, 0x28, 0x36 };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test TBZ with high bit (bit 40 in 64-bit register)
test "encoding: TBZ x1, #40, label" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const x1_preg = PReg.new(RegClass.int, 1);
    const x1 = Reg.fromPReg(x1_preg);

    // TBZ x1, #40, +4 (skip 1 instruction)
    try emit.emitTbz(x1, 40, 1, &buffer);

    // Expected: b5=1 (bit 40 = 0x28, b5=1, b40=8), op=011011, o=0, b40=8, imm14=1, Rt=1
    // Binary: 1|011011|0|01000|00000000000001|00001
    // Hex: 0xB7400021 (little-endian: 21 00 40 b7)
    const expected = [_]u8{ 0x21, 0x00, 0x40, 0xb7 };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test TBNZ encoding (Test Bit and Branch if Non-Zero)
// TBNZ: b5|011011|1|b40|imm14|Rt
test "encoding: TBNZ x2, #7, label" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const x2_preg = PReg.new(RegClass.int, 2);
    const x2 = Reg.fromPReg(x2_preg);

    // TBNZ x2, #7, +12 (skip 3 instructions)
    try emit.emitTbnz(x2, 7, 3, &buffer);

    // Expected: b5=0, op=011011, o=1, b40=7, imm14=3, Rt=2
    // Binary: 0|011011|1|00111|00000000000011|00010
    // Hex: 0x37380062 (little-endian: 62 00 38 37)
    const expected = [_]u8{ 0x62, 0x00, 0x38, 0x37 };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test TBNZ with high bit
test "encoding: TBNZ x3, #63, label" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const x3_preg = PReg.new(RegClass.int, 3);
    const x3 = Reg.fromPReg(x3_preg);

    // TBNZ x3, #63, +0 (self-loop)
    try emit.emitTbnz(x3, 63, 0, &buffer);

    // Expected: b5=1 (bit 63 = 0x3F, b5=1, b40=31), op=011011, o=1, b40=31, imm14=0, Rt=3
    // Binary: 1|011011|1|11111|00000000000000|00011
    // Hex: 0xB7F80003 (little-endian: 03 00 f8 b7)
    const expected = [_]u8{ 0x03, 0x00, 0xf8, 0xb7 };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test FP constant loading (LDR literal for SIMD/FP)
// LDR (literal, SIMD/FP): opc|011|V=1|00|imm19|Rt
test "encoding: FP load constant (64-bit)" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const d0_preg = PReg.new(RegClass.float, 0);
    const d0 = Reg.fromPReg(d0_preg);
    const dst = WritableReg.fromReg(d0);

    // Load 64-bit FP constant (e.g., 3.14159...)
    // Bit pattern: 0x400921FB54442D18
    try emit.emitFploadConst(dst.toReg(), 0x400921FB54442D18, .size64, &buffer);

    // Expected: opc=01 (64-bit), 011, V=1, 00, imm19=?, Rt=0
    // The exact encoding depends on constant pool offset
    // Just verify instruction starts with correct pattern
    const insn = buffer.data.items;
    try testing.expect(insn.len >= 4);

    // Check opcode pattern: opc=01, 011, V=1, 00 in upper bits
    // Binary pattern: 01|011|1|00|...
    // Upper byte should be 0x5C (01011100)
    try testing.expectEqual(@as(u8, 0x5c), insn[3] & 0xFC); // Mask lower 2 bits (part of imm19)
}

// Test FP constant loading (32-bit)
test "encoding: FP load constant (32-bit)" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const s1_preg = PReg.new(RegClass.float, 1);
    const s1 = Reg.fromPReg(s1_preg);
    const dst = WritableReg.fromReg(s1);

    // Load 32-bit FP constant (e.g., 2.5)
    // Bit pattern: 0x40200000
    try emit.emitFploadConst(dst.toReg(), 0x40200000, .size32, &buffer);

    const insn = buffer.data.items;
    try testing.expect(insn.len >= 4);

    // Check opcode pattern: opc=00, 011, V=1, 00 in upper bits
    // Binary pattern: 00|011|1|00|...
    // Upper byte should be 0x1C (00011100)
    try testing.expectEqual(@as(u8, 0x1c), insn[3] & 0xFC);

    // Check Rt=1 in lower byte
    try testing.expectEqual(@as(u8, 1), insn[0] & 0x1F);
}

// Test CCMP encoding (Conditional Compare Register)
// CCMP: sf|1|1|11010010|Rm|cond|0|0|Rn|0|nzcv
// Compares Rn with Rm if condition is true, else sets flags to nzcv
test "encoding: CCMP x0, x1, #0, EQ" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const CondCode = @import("../src/backends/aarch64/inst.zig").CondCode;
    const x0_preg = PReg.new(RegClass.int, 0);
    const x1_preg = PReg.new(RegClass.int, 1);
    const x0 = Reg.fromPReg(x0_preg);
    const x1 = Reg.fromPReg(x1_preg);

    // CCMP x0, x1, #0 (nzcv), EQ
    try emit.emitCcmp(x0, x1, 0, CondCode.eq, .size64, &buffer);

    // Expected: sf=1, op=1, S=1, opcode=11010010, Rm=1, cond=0 (EQ), o2=0, o3=0, Rn=0, o=0, nzcv=0
    // Binary: 1|1|1|11010010|00001|0000|0|0|00000|0|0000
    // Hex: 0xFA410000 (little-endian: 00 00 41 fa)
    const expected = [_]u8{ 0x00, 0x00, 0x41, 0xfa };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test CCMP with 32-bit operands and different condition
test "encoding: CCMP w2, w3, #15, LT" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const CondCode = @import("../src/backends/aarch64/inst.zig").CondCode;
    const w2_preg = PReg.new(RegClass.int, 2);
    const w3_preg = PReg.new(RegClass.int, 3);
    const w2 = Reg.fromPReg(w2_preg);
    const w3 = Reg.fromPReg(w3_preg);

    // CCMP w2, w3, #15 (nzcv=1111), LT (cond=0xB)
    try emit.emitCcmp(w2, w3, 15, CondCode.lt, .size32, &buffer);

    // Expected: sf=0, op=1, S=1, opcode=11010010, Rm=3, cond=B (LT), o2=0, o3=0, Rn=2, o=0, nzcv=F
    // Binary: 0|1|1|11010010|00011|1011|0|0|00010|0|1111
    // Hex: 0x7A43B04F (little-endian: 4f b0 43 7a)
    const expected = [_]u8{ 0x4f, 0xb0, 0x43, 0x7a };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test CCMP immediate form
// CCMP: sf|1|1|11010010|imm5|cond|1|0|Rn|0|nzcv
test "encoding: CCMP x0, #5, #0, EQ" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const CondCode = @import("../src/backends/aarch64/inst.zig").CondCode;
    const x0_preg = PReg.new(RegClass.int, 0);
    const x0 = Reg.fromPReg(x0_preg);

    // CCMP x0, #5, #0 (nzcv), EQ
    try emit.emitCcmpImm(x0, 5, 0, CondCode.eq, .size64, &buffer);

    // Expected: sf=1, op=1, S=1, opcode=11010010, imm5=5, cond=0 (EQ), o2=1, o3=0, Rn=0, o=0, nzcv=0
    // Binary: 1|1|1|11010010|00101|0000|1|0|00000|0|0000
    // Hex: 0xFA450800 (little-endian: 00 08 45 fa)
    const expected = [_]u8{ 0x00, 0x08, 0x45, 0xfa };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}

// Test CCMP immediate with different nzcv flags
test "encoding: CCMP w1, #10, #7, GT" {
    const allocator = testing.allocator;
    var buffer = MachBuffer.init(allocator);
    defer buffer.deinit();

    const CondCode = @import("../src/backends/aarch64/inst.zig").CondCode;
    const w1_preg = PReg.new(RegClass.int, 1);
    const w1 = Reg.fromPReg(w1_preg);

    // CCMP w1, #10, #7 (nzcv=0111), GT (cond=0xC)
    try emit.emitCcmpImm(w1, 10, 7, CondCode.gt, .size32, &buffer);

    // Expected: sf=0, op=1, S=1, opcode=11010010, imm5=10, cond=C (GT), o2=1, o3=0, Rn=1, o=0, nzcv=7
    // Binary: 0|1|1|11010010|01010|1100|1|0|00001|0|0111
    // Hex: 0x7A4AC827 (little-endian: 27 c8 4a 7a)
    const expected = [_]u8{ 0x27, 0xc8, 0x4a, 0x7a };
    try testing.expectEqualSlices(u8, &expected, buffer.data.items);
}
