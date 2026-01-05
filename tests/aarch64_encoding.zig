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
