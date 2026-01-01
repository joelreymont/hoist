//! Immediate operands for Cranelift instructions.
//!
//! Simple newtype wrappers for immediate values.
//! Ported from cranelift-codegen immediates.rs.

const std = @import("std");

/// 64-bit immediate signed integer operand.
pub const Imm64 = packed struct {
    value: i64,

    pub fn new(x: i64) Imm64 {
        return .{ .value = x };
    }

    pub fn bits(self: Imm64) i64 {
        return self.value;
    }
};

/// Unsigned 8-bit immediate integer operand.
///
/// Used for lane indexes in SIMD vectors and immediate bit counts.
pub const Uimm8 = u8;

/// 32-bit immediate signed offset.
///
/// Used for address offsets in load/store instructions.
pub const Offset32 = packed struct {
    value: i32,

    pub fn new(x: i32) Offset32 {
        return .{ .value = x };
    }

    pub fn bits(self: Offset32) i32 {
        return self.value;
    }
};

/// 16-bit immediate floating point operand (IEEE 754-2008 binary16).
pub const Ieee16 = packed struct {
    bits: u16,

    pub fn new(x: u16) Ieee16 {
        return .{ .bits = x };
    }

    pub fn toBits(self: Ieee16) u16 {
        return self.bits;
    }
};

/// 32-bit immediate floating point operand (IEEE 754-2008 binary32).
pub const Ieee32 = packed struct {
    bits: u32,

    pub fn new(x: u32) Ieee32 {
        return .{ .bits = x };
    }

    pub fn fromF32(x: f32) Ieee32 {
        return .{ .bits = @bitCast(x) };
    }

    pub fn toF32(self: Ieee32) f32 {
        return @bitCast(self.bits);
    }

    pub fn toBits(self: Ieee32) u32 {
        return self.bits;
    }
};

/// 64-bit immediate floating point operand (IEEE 754-2008 binary64).
pub const Ieee64 = packed struct {
    bits: u64,

    pub fn new(x: u64) Ieee64 {
        return .{ .bits = x };
    }

    pub fn fromF64(x: f64) Ieee64 {
        return .{ .bits = @bitCast(x) };
    }

    pub fn toF64(self: Ieee64) f64 {
        return @bitCast(self.bits);
    }

    pub fn toBits(self: Ieee64) u64 {
        return self.bits;
    }
};

// Tests
const testing = std.testing;

test "Imm64 basic" {
    const imm = Imm64.new(42);
    try testing.expectEqual(@as(i64, 42), imm.bits());
}

test "Offset32 basic" {
    const off = Offset32.new(-100);
    try testing.expectEqual(@as(i32, -100), off.bits());
}

test "Ieee32 roundtrip" {
    const val: f32 = 3.14;
    const imm = Ieee32.fromF32(val);
    const result = imm.toF32();
    try testing.expectEqual(val, result);
}

test "Ieee64 roundtrip" {
    const val: f64 = 2.718281828;
    const imm = Ieee64.fromF64(val);
    const result = imm.toF64();
    try testing.expectEqual(val, result);
}

test "Uimm8" {
    const lane: Uimm8 = 7;
    try testing.expectEqual(@as(u8, 7), lane);
}
