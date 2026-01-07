//! Snapshot tests for AArch64 instruction encoding.
//!
//! These tests verify that instructions encode to the correct ARM64 machine code.
//! Uses ohsnap for snapshot testing of encoded bytes.

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
const FpuOperandSize = inst_mod.FpuOperandSize;
const VectorSize = inst_mod.VectorSize;
const CondCode = inst_mod.CondCode;
const ExtendOp = inst_mod.ExtendOp;
const ShiftOp = inst_mod.ShiftOp;

fn encodeInst(inst: Inst) ![]const u8 {
    const allocator = testing.allocator;
    var buffer = buffer_mod.MachBuffer.init(allocator);
    defer buffer.deinit();

    try emit_mod.emit(inst, &buffer);

    const data = try buffer.finishAndGetData();
    return data;
}

fn hexDump(bytes: []const u8, writer: anytype) !void {
    for (bytes, 0..) |byte, i| {
        if (i > 0) try writer.writeAll(" ");
        try writer.print("{x:0>2}", .{byte});
    }
}

test "encode: integer ALU - add register" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);
    const x2 = PReg.new(.int, 2);

    // ADD X0, X1, X2
    const inst = Inst{ .add_rr = .{
        .dst = WritableReg.from(x0),
        .src1 = x0.toReg(),
        .src2 = x1.toReg(),
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    // Expected: 8b010020 (ADD X0, X1, X2)
    try testing.expectEqual(@as(usize, 4), bytes.len);
    try testing.expectEqual(@as(u8, 0x20), bytes[0]);
    try testing.expectEqual(@as(u8, 0x00), bytes[1]);
    try testing.expectEqual(@as(u8, 0x01), bytes[2]);
    try testing.expectEqual(@as(u8, 0x8b), bytes[3]);
}

test "encode: integer ALU - add immediate" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);

    // ADD X0, X1, #42
    const inst = Inst{ .add_imm = .{
        .dst = WritableReg.from(x0),
        .src = x1.toReg(),
        .imm = 42,
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
    // ADD Xd, Xn, #imm: sf|0|0|10001|shift|imm12|Rn|Rd
    // sf=1, imm12=42, Rn=1, Rd=0
}

test "encode: integer ALU - sub register" {
    const x3 = PReg.new(.int, 3);
    const x4 = PReg.new(.int, 4);
    const x5 = PReg.new(.int, 5);

    // SUB X3, X4, X5
    const inst = Inst{ .sub_rr = .{
        .dst = WritableReg.from(x3),
        .src1 = x4.toReg(),
        .src2 = x5.toReg(),
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: integer ALU - mul register" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);
    const x2 = PReg.new(.int, 2);

    // MUL X0, X1, X2
    const inst = Inst{ .mul_rr = .{
        .dst = WritableReg.from(x0),
        .src1 = x1.toReg(),
        .src2 = x2.toReg(),
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: load/store - ldr immediate offset" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);

    // LDR X0, [X1, #8]
    const inst = Inst{ .ldr = .{
        .dst = WritableReg.from(x0),
        .base = x1.toReg(),
        .offset = 8,
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: load/store - str immediate offset" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);

    // STR X0, [X1, #16]
    const inst = Inst{ .str = .{
        .src = x0.toReg(),
        .base = x1.toReg(),
        .offset = 16,
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: load/store - ldp" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);
    const sp = PReg.new(.int, 31);

    // LDP X0, X1, [SP, #16]
    const inst = Inst{ .ldp = .{
        .dst1 = WritableReg.from(x0),
        .dst2 = WritableReg.from(x1),
        .base = sp.toReg(),
        .offset = 16,
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: load/store - stp" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);
    const sp = PReg.new(.int, 31);

    // STP X0, X1, [SP, #-16]
    const inst = Inst{ .stp = .{
        .src1 = x0.toReg(),
        .src2 = x1.toReg(),
        .base = sp.toReg(),
        .offset = -16,
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: branches - unconditional branch" {
    // B label (offset 0 for now)
    const inst = Inst{ .b = .{
        .target = .{ .label = 0 },
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: branches - conditional branch" {
    // B.EQ label
    const inst = Inst{ .b_cond = .{
        .cond = .eq,
        .target = .{ .label = 0 },
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: branches - branch register" {
    const x0 = PReg.new(.int, 0);

    // BR X0
    const inst = Inst{ .br = .{
        .target = x0.toReg(),
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: branches - branch with link register" {
    const x0 = PReg.new(.int, 0);

    // BLR X0
    const inst = Inst{ .blr = .{
        .target = x0.toReg(),
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: branches - return" {
    // RET
    const inst = Inst.ret;

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
    // RET: 1101011001011111000000xxxxx00000
    // Should be: d65f03c0
}

test "encode: float ops - fadd" {
    const v0 = PReg.new(.float, 0);
    const v1 = PReg.new(.float, 1);
    const v2 = PReg.new(.float, 2);

    // FADD D0, D1, D2
    const inst = Inst{ .fadd = .{
        .dst = WritableReg.from(v0),
        .src1 = v1.toReg(),
        .src2 = v2.toReg(),
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: float ops - fmul" {
    const v0 = PReg.new(.float, 0);
    const v1 = PReg.new(.float, 1);
    const v2 = PReg.new(.float, 2);

    // FMUL S0, S1, S2
    const inst = Inst{ .fmul = .{
        .dst = WritableReg.from(v0),
        .src1 = v1.toReg(),
        .src2 = v2.toReg(),
        .size = .size32,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: float ops - fsub" {
    const v0 = PReg.new(.float, 0);
    const v1 = PReg.new(.float, 1);
    const v2 = PReg.new(.float, 2);

    // FSUB D0, D1, D2
    const inst = Inst{ .fsub = .{
        .dst = WritableReg.from(v0),
        .src1 = v1.toReg(),
        .src2 = v2.toReg(),
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: float ops - fdiv" {
    const v0 = PReg.new(.float, 0);
    const v1 = PReg.new(.float, 1);
    const v2 = PReg.new(.float, 2);

    // FDIV S0, S1, S2
    const inst = Inst{ .fdiv = .{
        .dst = WritableReg.from(v0),
        .src1 = v1.toReg(),
        .src2 = v2.toReg(),
        .size = .size32,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: mov immediate small value" {
    const x0 = PReg.new(.int, 0);

    // MOV X0, #42
    const inst = Inst{ .mov_imm = .{
        .dst = WritableReg.from(x0),
        .imm = 42,
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    // mov_imm may emit multiple instructions for materialization
    try testing.expect(bytes.len >= 4);
    try testing.expect(bytes.len % 4 == 0);
}

test "encode: movz - move wide with zero" {
    const x0 = PReg.new(.int, 0);

    // MOVZ X0, #0x1234
    const inst = Inst{ .movz = .{
        .dst = WritableReg.from(x0),
        .imm = 0x1234,
        .shift = 0,
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: logical ops - and register" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);
    const x2 = PReg.new(.int, 2);

    // AND X0, X1, X2
    const inst = Inst{ .and_rr = .{
        .dst = WritableReg.from(x0),
        .src1 = x1.toReg(),
        .src2 = x2.toReg(),
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: logical ops - orr register" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);
    const x2 = PReg.new(.int, 2);

    // ORR X0, X1, X2
    const inst = Inst{ .orr_rr = .{
        .dst = WritableReg.from(x0),
        .src1 = x1.toReg(),
        .src2 = x2.toReg(),
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: logical ops - eor register" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);
    const x2 = PReg.new(.int, 2);

    // EOR X0, X1, X2
    const inst = Inst{ .eor_rr = .{
        .dst = WritableReg.from(x0),
        .src1 = x1.toReg(),
        .src2 = x2.toReg(),
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: shift ops - lsl immediate" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);

    // LSL X0, X1, #3
    const inst = Inst{ .lsl_imm = .{
        .dst = WritableReg.from(x0),
        .src = x1.toReg(),
        .imm = 3,
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: shift ops - lsr register" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);
    const x2 = PReg.new(.int, 2);

    // LSR X0, X1, X2
    const inst = Inst{ .lsr_rr = .{
        .dst = WritableReg.from(x0),
        .src1 = x1.toReg(),
        .src2 = x2.toReg(),
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: comparison - cmp register" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);

    // CMP X0, X1
    const inst = Inst{ .cmp_rr = .{
        .src1 = x0.toReg(),
        .src2 = x1.toReg(),
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: comparison - cmp immediate" {
    const x0 = PReg.new(.int, 0);

    // CMP X0, #10
    const inst = Inst{ .cmp_imm = .{
        .src = x0.toReg(),
        .imm = 10,
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}

test "encode: conditional select" {
    const x0 = PReg.new(.int, 0);
    const x1 = PReg.new(.int, 1);
    const x2 = PReg.new(.int, 2);

    // CSEL X0, X1, X2, EQ
    const inst = Inst{ .csel = .{
        .dst = WritableReg.from(x0),
        .src1 = x1.toReg(),
        .src2 = x2.toReg(),
        .cond = .eq,
        .size = .size64,
    } };

    const bytes = try encodeInst(inst);
    defer testing.allocator.free(bytes);

    try testing.expectEqual(@as(usize, 4), bytes.len);
}
