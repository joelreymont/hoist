//! Trap codes describing the reason for a trap.
//!
//! Ported from cranelift-codegen trapcode.rs.

const std = @import("std");

/// A trap code describing the reason for a trap.
///
/// All trap instructions have an explicit trap code.
/// Uses u8 encoding where 0 is invalid and 251-255 are reserved for Cranelift.
pub const TrapCode = enum(u8) {
    _,

    /// Number of reserved opcodes for Cranelift itself.
    const RESERVED: u8 = 5;
    const RESERVED_START: u8 = 251; // 255 - 5 + 1

    /// The current stack space was exhausted.
    pub const stack_overflow = @as(TrapCode, @enumFromInt(RESERVED_START + 0));

    /// An integer arithmetic operation caused an overflow.
    pub const integer_overflow = @as(TrapCode, @enumFromInt(RESERVED_START + 1));

    /// A heap_addr instruction detected an out-of-bounds error.
    pub const heap_out_of_bounds = @as(TrapCode, @enumFromInt(RESERVED_START + 2));

    /// An integer division by zero.
    pub const integer_division_by_zero = @as(TrapCode, @enumFromInt(RESERVED_START + 3));

    /// Failed float-to-int conversion.
    pub const bad_conversion_to_integer = @as(TrapCode, @enumFromInt(RESERVED_START + 4));

    /// Create a user-defined trap code.
    ///
    /// Returns null if code is zero or too large (reserved by Cranelift).
    pub fn user(code: u8) ?TrapCode {
        if (code == 0 or code >= RESERVED_START) {
            return null;
        }
        return @enumFromInt(code);
    }

    /// Returns the raw byte representing this trap.
    pub fn toRaw(self: TrapCode) u8 {
        return @intFromEnum(self);
    }

    /// Creates a trap code from its raw byte.
    pub fn fromRaw(byte: u8) ?TrapCode {
        if (byte == 0) return null;
        return @enumFromInt(byte);
    }
};

// Tests
const testing = std.testing;

test "TrapCode reserved" {
    try testing.expectEqual(@as(u8, 251), TrapCode.stack_overflow.toRaw());
    try testing.expectEqual(@as(u8, 252), TrapCode.integer_overflow.toRaw());
    try testing.expectEqual(@as(u8, 253), TrapCode.heap_out_of_bounds.toRaw());
    try testing.expectEqual(@as(u8, 254), TrapCode.integer_division_by_zero.toRaw());
    try testing.expectEqual(@as(u8, 255), TrapCode.bad_conversion_to_integer.toRaw());
}

test "TrapCode user" {
    const t1 = TrapCode.user(1);
    try testing.expect(t1 != null);
    try testing.expectEqual(@as(u8, 1), t1.?.toRaw());

    const t250 = TrapCode.user(250);
    try testing.expect(t250 != null);
    try testing.expectEqual(@as(u8, 250), t250.?.toRaw());

    try testing.expectEqual(@as(?TrapCode, null), TrapCode.user(0));
    try testing.expectEqual(@as(?TrapCode, null), TrapCode.user(251));
    try testing.expectEqual(@as(?TrapCode, null), TrapCode.user(255));
}

test "TrapCode roundtrip" {
    const t = TrapCode.user(42).?;
    const raw = t.toRaw();
    const t2 = TrapCode.fromRaw(raw).?;
    try testing.expectEqual(t, t2);
}
