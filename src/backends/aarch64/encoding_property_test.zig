//! Property-based tests for AArch64 instruction encoding.
//!
//! Tests invariants and properties that should hold for all instructions.
//! Uses oracle functions to verify encoding correctness without needing
//! a full disassembler.

const std = @import("std");
const testing = std.testing;
const inst_mod = @import("inst.zig");
const emit_mod = @import("emit.zig");
const buffer_mod = @import("../../machinst/buffer.zig");

const Inst = inst_mod.Inst;
const Reg = inst_mod.Reg;
const PReg = inst_mod.PReg;
const WritableReg = inst_mod.WritableReg;
const OperandSize = inst_mod.OperandSize;

/// Encode instruction to bytes.
fn encodeInst(inst: Inst) ![]const u8 {
    const allocator = testing.allocator;
    var buffer = buffer_mod.MachBuffer.init(allocator);
    defer buffer.deinit();

    try emit_mod.emit(inst, &buffer);

    const data = buffer.finish();
    const copy = try allocator.dupe(u8, data);
    return copy;
}

/// Oracle: All AArch64 instructions are exactly 4 bytes (32 bits).
/// Exception: Multi-instruction sequences like mov_imm may emit multiple.
fn oracleInstructionLength(bytes: []const u8) bool {
    return bytes.len > 0 and bytes.len % 4 == 0;
}

/// Oracle: Extract opcode bits from encoded instruction.
/// Returns top 11 bits which identify instruction family.
fn oracleGetOpcodeBits(bytes: []const u8) u11 {
    std.debug.assert(bytes.len >= 4);
    // ARM64 is little-endian, reconstruct 32-bit word
    const word = @as(u32, bytes[0]) |
        (@as(u32, bytes[1]) << 8) |
        (@as(u32, bytes[2]) << 16) |
        (@as(u32, bytes[3]) << 24);
    // Top 11 bits
    return @truncate(word >> 21);
}

/// Oracle: Extract destination register from instruction encoding.
/// For most ALU/load/store, Rd is bits [4:0].
fn oracleGetDestReg(bytes: []const u8) u5 {
    std.debug.assert(bytes.len >= 4);
    return @truncate(bytes[0] & 0x1F);
}

/// Oracle: Extract source register 1 (Rn) from instruction.
/// For most instructions, Rn is bits [9:5].
fn oracleGetSrcReg1(bytes: []const u8) u5 {
    std.debug.assert(bytes.len >= 4);
    const word = @as(u32, bytes[0]) |
        (@as(u32, bytes[1]) << 8);
    return @truncate((word >> 5) & 0x1F);
}

/// Oracle: Extract source register 2 (Rm) from instruction.
/// For register-register ops, Rm is bits [20:16].
fn oracleGetSrcReg2(bytes: []const u8) u5 {
    std.debug.assert(bytes.len >= 4);
    const word = @as(u32, bytes[0]) |
        (@as(u32, bytes[1]) << 8) |
        (@as(u32, bytes[2]) << 16);
    return @truncate((word >> 16) & 0x1F);
}

test "property: all instructions encode to 4-byte multiples" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);
    const v0 = PReg.new(.float, 0);

    const test_cases = [_]Inst{
        Inst{ .add_rr = .{
            .dst = WritableReg.fromReg(Reg.fromPReg(x0)),
            .src1 = Reg.fromPReg(x0),
            .src2 = Reg.fromPReg(x1),
            .size = .size64,
        } },
        Inst{ .sub_rr = .{
            .dst = WritableReg.fromReg(Reg.fromPReg(x0)),
            .src1 = Reg.fromPReg(x0),
            .src2 = Reg.fromPReg(x1),
            .size = .size64,
        } },
        Inst{ .mul_rr = .{
            .dst = WritableReg.fromReg(Reg.fromPReg(x0)),
            .src1 = Reg.fromPReg(x0),
            .src2 = Reg.fromPReg(x1),
            .size = .size64,
        } },
        Inst{ .ldr = .{
            .dst = WritableReg.fromReg(Reg.fromPReg(x0)),
            .base = Reg.fromPReg(x1),
            .offset = 0,
            .size = .size64,
        } },
        Inst{ .str = .{
            .src = Reg.fromPReg(x0),
            .base = Reg.fromPReg(x1),
            .offset = 0,
            .size = .size64,
        } },
        Inst{ .fadd = .{
            .dst = WritableReg.fromReg(Reg.fromPReg(v0)),
            .src1 = Reg.fromPReg(v0),
            .src2 = Reg.fromPReg(v0),
            .size = .size64,
        } },
        Inst.ret,
    };

    for (test_cases) |inst| {
        const bytes = try encodeInst(inst);
        defer testing.allocator.free(bytes);

        try testing.expect(oracleInstructionLength(bytes));
    }
}

test "property: register numbers preserved in encoding" {
    // For each register pair, verify encoding preserves register numbers
    const test_cases = [_]struct { src_reg: u5, expected: u5 }{
        .{ .src_reg = 0, .expected = 0 },
        .{ .src_reg = 1, .expected = 1 },
        .{ .src_reg = 7, .expected = 7 },
        .{ .src_reg = 15, .expected = 15 },
        .{ .src_reg = 30, .expected = 30 },
    };

    for (test_cases) |tc| {
        const dst = PReg.new(.int, 0);
        const src1 = PReg.new(.int, tc.src_reg);
        const src2 = PReg.new(.int, tc.src_reg);

        // Test ADD instruction: ADD X0, Xn, Xm
        const inst = Inst{ .add_rr = .{
            .dst = WritableReg.fromReg(Reg.fromPReg(dst)),
            .src1 = Reg.fromPReg(src1),
            .src2 = Reg.fromPReg(src2),
            .size = .size64,
        } };

        const bytes = try encodeInst(inst);
        defer testing.allocator.free(bytes);

        try testing.expectEqual(tc.expected, oracleGetSrcReg1(bytes));
        try testing.expectEqual(tc.expected, oracleGetSrcReg2(bytes));
    }
}

test "property: destination register encoding" {
    // Test that destination register is correctly encoded in Rd field
    const test_cases = [_]u5{ 0, 1, 5, 10, 15, 20, 30 };

    for (test_cases) |dst_num| {
        const dst = PReg.new(.int, dst_num);
        const src = PReg.new(.int, 0);

        const inst = Inst{ .add_rr = .{
            .dst = WritableReg.fromReg(Reg.fromPReg(dst)),
            .src1 = Reg.fromPReg(src),
            .src2 = Reg.fromPReg(src),
            .size = .size64,
        } };

        const bytes = try encodeInst(inst);
        defer testing.allocator.free(bytes);

        try testing.expectEqual(dst_num, oracleGetDestReg(bytes));
    }
}

test "property: immediate bounds checking" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);

    // Valid 12-bit immediate (0-4095)
    {
        const inst = Inst{ .add_imm = .{
            .dst = WritableReg.fromReg(Reg.fromPReg(x0)),
            .src = Reg.fromPReg(x1),
            .imm = 4095,
            .size = .size64,
        } };

        const bytes = try encodeInst(inst);
        defer testing.allocator.free(bytes);

        try testing.expect(oracleInstructionLength(bytes));
    }

    // Immediate at boundary
    {
        const inst = Inst{ .add_imm = .{
            .dst = WritableReg.fromReg(Reg.fromPReg(x0)),
            .src = Reg.fromPReg(x1),
            .imm = 0,
            .size = .size64,
        } };

        const bytes = try encodeInst(inst);
        defer testing.allocator.free(bytes);

        try testing.expect(oracleInstructionLength(bytes));
    }
}

test "property: paired load/store offset alignment" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);
    const sp = PReg.new(.int, 31);

    // STP/LDP require 8-byte aligned offsets (for 64-bit)
    const valid_offsets = [_]i16{ -512, -256, -16, 0, 16, 256, 504 };

    for (valid_offsets) |offset| {
        const inst = Inst{ .stp = .{
            .src1 = Reg.fromPReg(x0),
            .src2 = Reg.fromPReg(x1),
            .base = Reg.fromPReg(sp),
            .offset = offset,
            .size = .size64,
        } };

        const bytes = try encodeInst(inst);
        defer testing.allocator.free(bytes);

        try testing.expectEqual(@as(usize, 4), bytes.len);
        try testing.expect(oracleInstructionLength(bytes));
    }
}

test "property: size bit consistency" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);

    // Test 32-bit vs 64-bit encoding
    const sizes = [_]OperandSize{ .size32, .size64 };

    for (sizes) |size| {
        const inst = Inst{ .add_rr = .{
            .dst = WritableReg.fromReg(Reg.fromPReg(x0)),
            .src1 = Reg.fromPReg(x1),
            .src2 = Reg.fromPReg(x1),
            .size = size,
        } };

        const bytes = try encodeInst(inst);
        defer testing.allocator.free(bytes);

        try testing.expectEqual(@as(usize, 4), bytes.len);

        // Bit 31 (sf) should be 1 for size64, 0 for size32
        const word = @as(u32, bytes[0]) |
            (@as(u32, bytes[1]) << 8) |
            (@as(u32, bytes[2]) << 16) |
            (@as(u32, bytes[3]) << 24);
        const sf_bit = (word >> 31) & 1;

        if (size == .size64) {
            try testing.expectEqual(@as(u1, 1), @as(u1, @truncate(sf_bit)));
        } else {
            try testing.expectEqual(@as(u1, 0), @as(u1, @truncate(sf_bit)));
        }
    }
}

test "property: move instructions preserve register class" {
    // Integer register to integer register
    {
        const x0 = PReg.new(.int, 0);
        const x1 = PReg.new(.int, 1);

        const inst = Inst{ .mov_rr = .{
            .dst = WritableReg.fromReg(Reg.fromPReg(x0)),
            .src = Reg.fromPReg(x1),
            .size = .size64,
        } };

        const bytes = try encodeInst(inst);
        defer testing.allocator.free(bytes);

        try testing.expect(oracleInstructionLength(bytes));
        // Should encode as ORR Xd, XZR, Xm
    }

    // Float register to float register
    {
        const v0 = PReg.new(.float, 0);
        const v1 = PReg.new(.float, 1);

        const inst = Inst{ .fmov = .{
            .dst = WritableReg.fromReg(Reg.fromPReg(v0)),
            .src = Reg.fromPReg(v1),
            .size = .size64,
        } };

        const bytes = try encodeInst(inst);
        defer testing.allocator.free(bytes);

        try testing.expect(oracleInstructionLength(bytes));
    }
}

test "property: conditional branch encoding" {
    const cond_codes = [_]inst_mod.CondCode{
        .eq, .ne, .cs, .cc, .mi, .pl, .vs, .vc,
        .hi, .ls, .ge, .lt, .gt, .le, .al,
    };

    for (cond_codes) |cond| {
        const inst = Inst{ .b_cond = .{
            .cond = cond,
            .target = .{ .label = 0 },
        } };

        const bytes = try encodeInst(inst);
        defer testing.allocator.free(bytes);

        try testing.expectEqual(@as(usize, 4), bytes.len);

        // B.cond has specific opcode pattern
        const opcode = oracleGetOpcodeBits(bytes);
        // B.cond opcode: 0101010_0xxx (01010100 in bits [31:24])
        try testing.expect(opcode >> 4 == 0b0101010);
    }
}

test "property: ret instruction is constant encoding" {
    // RET should always encode to same bytes (RET defaults to X30/LR)
    const inst = Inst.ret;

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);

    // RET: D65F03C0 (constant)
    try testing.expectEqual(@as(u8, 0xC0), bytes[0]);
    try testing.expectEqual(@as(u8, 0x03), bytes[1]);
    try testing.expectEqual(@as(u8, 0x5F), bytes[2]);
    try testing.expectEqual(@as(u8, 0xD6), bytes[3]);
}
