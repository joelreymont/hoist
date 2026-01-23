const std = @import("std");
const testing = std.testing;

const root = @import("root");
const emit = root.x64_emit.emit;
const Inst = root.x64_inst.Inst;
const OperandSize = root.x64_inst.OperandSize;
const Reg = root.x64_inst.Reg;
const Mem = root.x64_inst.Mem;
const buffer_mod = root.buffer;

test "emit mov [base+disp8], reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);

    const mem = Mem.base_disp(r0, 8);
    try emit(.{ .mov_mr = .{
        .dst = mem,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    // REX.W + 0x89 + ModR/M + disp8
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x89), buffer.data.items[1]); // MOV r/m, r
}

test "emit mov reg, [base]" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    const mem = Mem.base_only(r0);
    try emit(.{ .mov_rm = .{
        .dst = wr1,
        .src = mem,
        .size = .size64,
    } }, &buffer);

    // REX.W + 0x8B + ModR/M
    try testing.expectEqual(@as(usize, 3), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x8B), buffer.data.items[1]); // MOV r, r/m
}

test "emit lea reg, [base+disp8]" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    const mem = Mem.base_disp(r0, 16);
    try emit(.{ .lea = .{
        .dst = wr1,
        .src = mem,
    } }, &buffer);

    // REX.W + 0x8D + ModR/M + disp8
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x8D), buffer.data.items[1]); // LEA
}

test "emit lock cmpxchg [mem], reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);

    const mem = Mem.base_only(r0);
    try emit(.{ .cmpxchg_mr = .{
        .dst = mem,
        .src = r1,
        .size = .size32,
    } }, &buffer);

    // LOCK + REX (optional) + 0x0F 0xB1 + ModR/M
    try testing.expect(buffer.data.items.len >= 4);
    try testing.expectEqual(@as(u8, 0xF0), buffer.data.items[0]); // LOCK prefix
}

test "emit lock xadd [mem], reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    const mem = Mem.base_disp(r0, 0);
    try emit(.{ .xadd_mr = .{
        .dst = mem,
        .src = wr1,
        .size = .size64,
    } }, &buffer);

    // LOCK + REX.W + 0x0F 0xC1 + ModR/M
    try testing.expect(buffer.data.items.len >= 5);
    try testing.expectEqual(@as(u8, 0xF0), buffer.data.items[0]); // LOCK prefix
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[1]); // REX.W
}

test "emit xchg [mem], reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    const mem = Mem.base_only(r0);
    try emit(.{ .xchg_mr = .{
        .dst = mem,
        .src = wr1,
        .size = .size32,
    } }, &buffer);

    // 0x87 + ModR/M (no LOCK prefix needed for XCHG)
    try testing.expect(buffer.data.items.len >= 2);
    try testing.expectEqual(@as(u8, 0x87), buffer.data.items[0]);
}

test "emit lock add [mem], imm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);

    const mem = Mem.base_disp(r0, 16);
    try emit(.{ .lock_add_mi = .{
        .dst = mem,
        .imm = 5,
        .size = .size64,
    } }, &buffer);

    // LOCK + REX.W + 0x83 + ModR/M + imm8
    try testing.expect(buffer.data.items.len >= 5);
    try testing.expectEqual(@as(u8, 0xF0), buffer.data.items[0]); // LOCK prefix
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[1]); // REX.W
    try testing.expectEqual(@as(u8, 0x83), buffer.data.items[2]); // ADD r/m, simm8
}

test "emit fence instructions" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try emit(.lfence, &buffer);
    try testing.expectEqual(@as(usize, 3), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[0]);
    try testing.expectEqual(@as(u8, 0xAE), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0xE8), buffer.data.items[2]);

    buffer.data.clearRetainingCapacity();

    try emit(.sfence, &buffer);
    try testing.expectEqual(@as(usize, 3), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[0]);
    try testing.expectEqual(@as(u8, 0xAE), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0xF8), buffer.data.items[2]);

    buffer.data.clearRetainingCapacity();

    try emit(.mfence, &buffer);
    try testing.expectEqual(@as(usize, 3), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[0]);
    try testing.expectEqual(@as(u8, 0xAE), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0xF0), buffer.data.items[2]);
}

test "emit sib [base+idx*4+disp8]" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    const mem = Mem.new(r0, r1, 4, 8);
    try emit(.{ .mov_mr = .{
        .dst = mem,
        .src = r2,
        .size = .size64,
    } }, &buffer);

    // REX.W + 0x89 + ModR/M + SIB + disp8
    try testing.expectEqual(@as(usize, 5), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x89), buffer.data.items[1]); // MOV r/m, r
}

test "emit mov [base+disp32], reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);

    const mem = Mem.base_disp(r0, 1000);
    try emit(.{ .mov_mr = .{
        .dst = mem,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    // REX.W + 0x89 + ModR/M + disp32
    try testing.expectEqual(@as(usize, 7), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x89), buffer.data.items[1]); // MOV r/m, r
}

test "emit mov [disp32], reg (rip-relative)" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);

    const mem = Mem.new(null, null, 1, 0x1000);
    try emit(.{ .mov_mr = .{
        .dst = mem,
        .src = r0,
        .size = .size64,
    } }, &buffer);

    // REX.W + 0x89 + ModR/M + disp32
    try testing.expectEqual(@as(usize, 7), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x89), buffer.data.items[1]); // MOV r/m, r
    try testing.expectEqual(@as(u8, 0x05), buffer.data.items[2]); // ModR/M: mod=00, reg=0, rm=101
}

test "emit add reg, reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);
    const r1 = Reg.fromVReg(v1);

    try emit(.{ .add_rr = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    // REX.W + 0x01 + ModR/M
    try testing.expectEqual(@as(usize, 3), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x01), buffer.data.items[1]); // ADD
}

test "emit sub reg, imm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .sub_imm = .{
        .dst = wr0,
        .imm = 16,
        .size = .size64,
    } }, &buffer);

    // REX.W + 0x83 + ModR/M + imm8
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
}

test "emit and reg, reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);
    const r1 = Reg.fromVReg(v1);

    try emit(.{ .and_rr = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x21), buffer.data.items[1]); // AND
}

test "emit or reg, imm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .or_imm = .{
        .dst = wr0,
        .imm = 0xFF,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(u8, 0x81), buffer.data.items[0]); // OR imm32
}

test "emit xor reg, reg (zero idiom)" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .xor_rr = .{
        .dst = wr0,
        .src = r0,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(u8, 0x31), buffer.data.items[1]); // XOR
}

test "emit cmp reg, reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);

    try emit(.{ .cmp_rr = .{
        .lhs = r0,
        .rhs = r1,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[0]); // REX.W
    try testing.expectEqual(@as(u8, 0x39), buffer.data.items[1]); // CMP
}

test "emit test reg, imm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);

    try emit(.{ .test_imm = .{
        .lhs = r0,
        .imm = 1,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(u8, 0xF7), buffer.data.items[0]); // TEST imm
}

test "emit push reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);

    try emit(.{ .push_r = .{ .src = r0 } }, &buffer);

    try testing.expectEqual(@as(usize, 1), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x50), buffer.data.items[0]); // PUSH rax
}

test "emit pop reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .pop_r = .{ .dst = wr0 } }, &buffer);

    try testing.expectEqual(@as(usize, 1), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x58), buffer.data.items[0]); // POP rax
}

test "emit ret" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try emit(.ret, &buffer);

    try testing.expectEqual(@as(usize, 1), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0xC3), buffer.data.items[0]); // RET
}

test "emit lock cmpxchg [mem], reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);

    const mem = Mem.base_only(r0);
    try emit(.{ .cmpxchg_mr = .{
        .dst = mem,
        .src = r1,
        .size = .size32,
    } }, &buffer);

    // LOCK + 0x0F 0xB1 + ModR/M
    try testing.expect(buffer.data.items.len >= 4);
    try testing.expectEqual(@as(u8, 0xF0), buffer.data.items[0]); // LOCK prefix
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0xB1), buffer.data.items[2]); // CMPXCHG
}

test "emit lock xadd [mem], reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    const mem = Mem.base_disp(r0, 0);
    try emit(.{ .xadd_mr = .{
        .dst = mem,
        .src = wr1,
        .size = .size64,
    } }, &buffer);

    // LOCK + REX.W + 0x0F 0xC1 + ModR/M
    try testing.expect(buffer.data.items.len >= 5);
    try testing.expectEqual(@as(u8, 0xF0), buffer.data.items[0]); // LOCK prefix
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[1]); // REX.W
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[2]);
    try testing.expectEqual(@as(u8, 0xC1), buffer.data.items[3]); // XADD
}

test "emit xchg [mem], reg" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    const mem = Mem.base_only(r0);
    try emit(.{ .xchg_mr = .{
        .dst = mem,
        .src = wr1,
        .size = .size32,
    } }, &buffer);

    // 0x87 + ModR/M
    try testing.expect(buffer.data.items.len >= 2);
    try testing.expectEqual(@as(u8, 0x87), buffer.data.items[0]);
}

test "emit lock add [mem], imm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);

    const mem = Mem.base_disp(r0, 16);
    try emit(.{ .lock_add_mi = .{
        .dst = mem,
        .imm = 5,
        .size = .size64,
    } }, &buffer);

    // LOCK + REX.W + 0x83 + ModR/M + imm8
    try testing.expect(buffer.data.items.len >= 5);
    try testing.expectEqual(@as(u8, 0xF0), buffer.data.items[0]); // LOCK prefix
    try testing.expectEqual(@as(u8, 0x48), buffer.data.items[1]); // REX.W
    try testing.expectEqual(@as(u8, 0x83), buffer.data.items[2]); // ADD r/m, simm8
}

test "emit fence instructions" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try emit(.lfence, &buffer);
    try testing.expectEqual(@as(usize, 3), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[0]);
    try testing.expectEqual(@as(u8, 0xAE), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0xE8), buffer.data.items[2]);

    buffer.data.clearRetainingCapacity();

    try emit(.sfence, &buffer);
    try testing.expectEqual(@as(usize, 3), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[0]);
    try testing.expectEqual(@as(u8, 0xAE), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0xF8), buffer.data.items[2]);

    buffer.data.clearRetainingCapacity();

    try emit(.mfence, &buffer);
    try testing.expectEqual(@as(usize, 3), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[0]);
    try testing.expectEqual(@as(u8, 0xAE), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0xF0), buffer.data.items[2]);
}

test "emit nop" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try emit(.nop, &buffer);

    try testing.expectEqual(@as(usize, 1), buffer.data.items.len);
    try testing.expectEqual(@as(u8, 0x90), buffer.data.items[0]); // NOP
}
