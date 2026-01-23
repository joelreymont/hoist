const std = @import("std");
const testing = std.testing;

const root = @import("root");
const emit = root.x64_emit.emit;
const Inst = root.x64_inst.Inst;
const Reg = root.x64_inst.Reg;
const buffer_mod = root.buffer;

test "emit movdqa xmm, xmm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .vec);
    const v1 = root.reg.VReg.new(1, .vec);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    try emit(.{ .movdqa_rr = .{
        .dst = wr1,
        .src = r0,
    } }, &buffer);

    // 0x66 0x0F 0x6F + ModR/M
    try testing.expect(buffer.data.items.len >= 3);
    try testing.expectEqual(@as(u8, 0x66), buffer.data.items[0]); // SSE2 prefix
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0x6F), buffer.data.items[2]); // MOVDQA
}

test "emit movdqu xmm, xmm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .vec);
    const v1 = root.reg.VReg.new(1, .vec);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    try emit(.{ .movdqu_rr = .{
        .dst = wr1,
        .src = r0,
    } }, &buffer);

    // 0xF3 0x0F 0x6F + ModR/M
    try testing.expect(buffer.data.items.len >= 3);
    try testing.expectEqual(@as(u8, 0xF3), buffer.data.items[0]); // Unaligned prefix
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0x6F), buffer.data.items[2]); // MOVDQU
}

test "emit paddd xmm, xmm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .vec);
    const v1 = root.reg.VReg.new(1, .vec);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    try emit(.{ .paddd_rr = .{
        .dst = wr1,
        .src = r0,
    } }, &buffer);

    // 0x66 0x0F 0xFE + ModR/M
    try testing.expect(buffer.data.items.len >= 3);
    try testing.expectEqual(@as(u8, 0x66), buffer.data.items[0]); // SSE2 prefix
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0xFE), buffer.data.items[2]); // PADDD
}

test "emit pxor xmm, xmm (zero idiom)" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .vec);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .pxor_rr = .{
        .dst = wr0,
        .src = r0,
    } }, &buffer);

    // 0x66 0x0F 0xEF + ModR/M
    try testing.expect(buffer.data.items.len >= 3);
    try testing.expectEqual(@as(u8, 0x66), buffer.data.items[0]); // SSE2 prefix
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0xEF), buffer.data.items[2]); // PXOR
}

test "emit addps xmm, xmm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .vec);
    const v1 = root.reg.VReg.new(1, .vec);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    try emit(.{ .addps_rr = .{
        .dst = wr1,
        .src = r0,
    } }, &buffer);

    // 0x0F 0x58 + ModR/M (no prefix for SSE)
    try testing.expect(buffer.data.items.len >= 2);
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[0]);
    try testing.expectEqual(@as(u8, 0x58), buffer.data.items[1]); // ADDPS
}

test "emit addpd xmm, xmm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .vec);
    const v1 = root.reg.VReg.new(1, .vec);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    try emit(.{ .addpd_rr = .{
        .dst = wr1,
        .src = r0,
    } }, &buffer);

    // 0x66 0x0F 0x58 + ModR/M
    try testing.expect(buffer.data.items.len >= 3);
    try testing.expectEqual(@as(u8, 0x66), buffer.data.items[0]); // SSE2 prefix
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0x58), buffer.data.items[2]); // ADDPD
}

test "emit movss xmm, xmm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .vec);
    const v1 = root.reg.VReg.new(1, .vec);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    try emit(.{ .movss_rr = .{
        .dst = wr1,
        .src = r0,
    } }, &buffer);

    // 0xF3 0x0F 0x10 + ModR/M
    try testing.expect(buffer.data.items.len >= 3);
    try testing.expectEqual(@as(u8, 0xF3), buffer.data.items[0]); // Scalar SS prefix
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0x10), buffer.data.items[2]); // MOVSS
}

test "emit movsd xmm, xmm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .vec);
    const v1 = root.reg.VReg.new(1, .vec);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    try emit(.{ .movsd_rr = .{
        .dst = wr1,
        .src = r0,
    } }, &buffer);

    // 0xF2 0x0F 0x10 + ModR/M
    try testing.expect(buffer.data.items.len >= 3);
    try testing.expectEqual(@as(u8, 0xF2), buffer.data.items[0]); // Scalar SD prefix
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0x10), buffer.data.items[2]); // MOVSD
}

test "emit pshufd xmm, xmm, imm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .vec);
    const v1 = root.reg.VReg.new(1, .vec);
    const r0 = Reg.fromVReg(v0);
    const wr1 = root.reg.WritableReg.fromReg(Reg.fromVReg(v1));

    try emit(.{ .pshufd_rr = .{
        .dst = wr1,
        .src = r0,
        .imm = 0b11_10_01_00, // Identity shuffle
    } }, &buffer);

    // 0x66 0x0F 0x70 + ModR/M + imm8
    try testing.expect(buffer.data.items.len >= 4);
    try testing.expectEqual(@as(u8, 0x66), buffer.data.items[0]); // SSE2 prefix
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0x70), buffer.data.items[2]); // PSHUFD
}

test "emit pslld xmm, imm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .vec);
    const wr0 = root.reg.WritableReg.fromReg(Reg.fromVReg(v0));

    try emit(.{ .pslld_imm = .{
        .dst = wr0,
        .count = 4,
    } }, &buffer);

    // 0x66 0x0F 0xF2 + ModR/M + imm8
    try testing.expect(buffer.data.items.len >= 4);
    try testing.expectEqual(@as(u8, 0x66), buffer.data.items[0]); // SSE2 prefix
    try testing.expectEqual(@as(u8, 0x0F), buffer.data.items[1]);
    try testing.expectEqual(@as(u8, 0xF2), buffer.data.items[2]); // PSLLD
}
