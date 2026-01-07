//! Unit tests for register types.

const std = @import("std");
const testing = std.testing;
const reg_mod = @import("reg.zig");

const RegClass = reg_mod.RegClass;
const PReg = reg_mod.PReg;
const VReg = reg_mod.VReg;
const Reg = reg_mod.Reg;

// RegClass tests

test "RegClass: count is correct" {
    try testing.expectEqual(@as(u8, 3), RegClass.count);
}

test "RegClass: index returns correct values" {
    try testing.expectEqual(@as(u8, 0), RegClass.int.index());
    try testing.expectEqual(@as(u8, 1), RegClass.float.index());
    try testing.expectEqual(@as(u8, 2), RegClass.vector.index());
}

test "RegClass: all classes have unique indices" {
    try testing.expect(RegClass.int.index() != RegClass.float.index());
    try testing.expect(RegClass.int.index() != RegClass.vector.index());
    try testing.expect(RegClass.float.index() != RegClass.vector.index());
}

// PReg tests

test "PReg.new: basic construction" {
    const preg = PReg.new(.int, 5);
    try testing.expectEqual(RegClass.int, preg.class());
    try testing.expectEqual(@as(u6, 5), preg.hwEnc());
}

test "PReg.new: all register classes" {
    const int_reg = PReg.new(.int, 10);
    const float_reg = PReg.new(.float, 20);
    const vec_reg = PReg.new(.vector, 30);

    try testing.expectEqual(RegClass.int, int_reg.class());
    try testing.expectEqual(RegClass.float, float_reg.class());
    try testing.expectEqual(RegClass.vector, vec_reg.class());

    try testing.expectEqual(@as(u6, 10), int_reg.hwEnc());
    try testing.expectEqual(@as(u6, 20), float_reg.hwEnc());
    try testing.expectEqual(@as(u6, 30), vec_reg.hwEnc());
}

test "PReg.new: encoding roundtrip" {
    const test_cases = [_]struct { class: RegClass, hw: u6 }{
        .{ .class = .int, .hw = 0 },
        .{ .class = .int, .hw = 31 },
        .{ .class = .int, .hw = 63 },
        .{ .class = .float, .hw = 0 },
        .{ .class = .float, .hw = 31 },
        .{ .class = .vector, .hw = 0 },
        .{ .class = .vector, .hw = 31 },
    };

    for (test_cases) |tc| {
        const preg = PReg.new(tc.class, tc.hw);
        try testing.expectEqual(tc.class, preg.class());
        try testing.expectEqual(tc.hw, preg.hwEnc());
    }
}

test "PReg: max hw_enc is 63 (6 bits)" {
    const preg = PReg.new(.int, 63);
    try testing.expectEqual(@as(u6, 63), preg.hwEnc());
}

test "PReg: same class and hw_enc produce same bits" {
    const p1 = PReg.new(.int, 15);
    const p2 = PReg.new(.int, 15);
    try testing.expectEqual(p1.bits, p2.bits);
}

test "PReg: different class or hw_enc produce different bits" {
    const p1 = PReg.new(.int, 15);
    const p2 = PReg.new(.float, 15);
    const p3 = PReg.new(.int, 16);

    try testing.expect(p1.bits != p2.bits);
    try testing.expect(p1.bits != p3.bits);
}

// VReg tests

test "VReg.new: basic construction" {
    const vreg = VReg.new(42, .int);
    try testing.expectEqual(@as(u32, 42), vreg.index());
    try testing.expectEqual(RegClass.int, vreg.class());
}

test "VReg.new: all register classes" {
    const int_vreg = VReg.new(100, .int);
    const float_vreg = VReg.new(200, .float);
    const vec_vreg = VReg.new(300, .vector);

    try testing.expectEqual(RegClass.int, int_vreg.class());
    try testing.expectEqual(RegClass.float, float_vreg.class());
    try testing.expectEqual(RegClass.vector, vec_vreg.class());

    try testing.expectEqual(@as(u32, 100), int_vreg.index());
    try testing.expectEqual(@as(u32, 200), float_vreg.index());
    try testing.expectEqual(@as(u32, 300), vec_vreg.index());
}

test "VReg.new: encoding roundtrip" {
    const test_cases = [_]struct { idx: u32, class: RegClass }{
        .{ .idx = 0, .class = .int },
        .{ .idx = 1, .class = .int },
        .{ .idx = 1000, .class = .int },
        .{ .idx = 100000, .class = .float },
        .{ .idx = 1000000, .class = .vector },
        .{ .idx = 0x3FFF_FFFF, .class = .int }, // Max index (30 bits)
    };

    for (test_cases) |tc| {
        const vreg = VReg.new(tc.idx, tc.class);
        try testing.expectEqual(tc.idx, vreg.index());
        try testing.expectEqual(tc.class, vreg.class());
    }
}

test "VReg: max index is 0x3FFFFFFF (30 bits)" {
    const vreg = VReg.new(0x3FFF_FFFF, .int);
    try testing.expectEqual(@as(u32, 0x3FFF_FFFF), vreg.index());
}

test "VReg: same class and index produce same bits" {
    const v1 = VReg.new(123, .float);
    const v2 = VReg.new(123, .float);
    try testing.expectEqual(v1.bits, v2.bits);
}

test "VReg: different class or index produce different bits" {
    const v1 = VReg.new(123, .int);
    const v2 = VReg.new(123, .float);
    const v3 = VReg.new(124, .int);

    try testing.expect(v1.bits != v2.bits);
    try testing.expect(v1.bits != v3.bits);
}

// Reg tests

test "Reg.fromVReg: basic conversion" {
    const vreg = VReg.new(42, .int);
    const reg = Reg.fromVReg(vreg);
    try testing.expectEqual(vreg.bits, reg.bits);
}

test "Reg.fromPReg: basic conversion" {
    const preg = PReg.new(.int, 10);
    const reg = Reg.fromPReg(preg);

    // PReg should map to a pinned VReg
    try testing.expect(reg.bits < Reg.PINNED_VREGS);
}

test "Reg.fromPReg: different pregs map to different regs" {
    const p1 = PReg.new(.int, 5);
    const p2 = PReg.new(.int, 6);
    const p3 = PReg.new(.float, 5);

    const r1 = Reg.fromPReg(p1);
    const r2 = Reg.fromPReg(p2);
    const r3 = Reg.fromPReg(p3);

    try testing.expect(r1.bits != r2.bits);
    try testing.expect(r1.bits != r3.bits);
}

test "Reg: PINNED_VREGS has expected value" {
    // Should accommodate 64 registers per class × 3 classes
    try testing.expectEqual(@as(usize, 192), Reg.PINNED_VREGS);
}

// Cross-type tests

test "PReg and VReg: classes are compatible" {
    const preg = PReg.new(.float, 15);
    const vreg = VReg.new(100, .float);

    try testing.expectEqual(preg.class(), vreg.class());
}

test "PReg and VReg: encoding independence" {
    // PReg with hw_enc=5 and VReg with index=5 should be different
    const preg = PReg.new(.int, 5);
    const vreg = VReg.new(5, .int);

    // They have same class but different meanings
    try testing.expectEqual(preg.class(), vreg.class());
    try testing.expect(preg.bits != vreg.bits);
}

test "Reg.fromPReg roundtrip preserves class" {
    const classes = [_]RegClass{ .int, .float, .vector };
    for (classes) |rc| {
        const preg = PReg.new(rc, 10);
        const reg = Reg.fromPReg(preg);

        // The reg should encode a vreg with the same class
        const vreg = VReg{ .bits = reg.bits };
        try testing.expectEqual(rc, vreg.class());
    }
}

test "VReg: zero index is valid" {
    const vreg = VReg.new(0, .int);
    try testing.expectEqual(@as(u32, 0), vreg.index());
    try testing.expectEqual(RegClass.int, vreg.class());
}

test "PReg: zero hw_enc is valid" {
    const preg = PReg.new(.int, 0);
    try testing.expectEqual(@as(u6, 0), preg.hwEnc());
    try testing.expectEqual(RegClass.int, preg.class());
}

test "RegClass: enum values are sequential" {
    try testing.expectEqual(@as(u8, 0), @intFromEnum(RegClass.int));
    try testing.expectEqual(@as(u8, 1), @intFromEnum(RegClass.float));
    try testing.expectEqual(@as(u8, 2), @intFromEnum(RegClass.vector));
}
