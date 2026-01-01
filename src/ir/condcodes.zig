//! Condition codes for comparing integers and floats.
//!
//! Ported from cranelift-codegen condcodes.rs.

const std = @import("std");

/// Condition code for comparing integers.
///
/// Used by the icmp instruction to compare integer values.
pub const IntCC = enum(u8) {
    /// ==
    eq,
    /// !=
    ne,
    /// Signed <
    slt,
    /// Signed >=
    sge,
    /// Signed >
    sgt,
    /// Signed <=
    sle,
    /// Unsigned <
    ult,
    /// Unsigned >=
    uge,
    /// Unsigned >
    ugt,
    /// Unsigned <=
    ule,

    /// Get the complemented condition code.
    ///
    /// The complemented condition code produces the opposite result.
    pub fn complement(self: IntCC) IntCC {
        return switch (self) {
            .eq => .ne,
            .ne => .eq,
            .slt => .sge,
            .sge => .slt,
            .sgt => .sle,
            .sle => .sgt,
            .ult => .uge,
            .uge => .ult,
            .ugt => .ule,
            .ule => .ugt,
        };
    }

    /// Get the swapped args condition code.
    ///
    /// The swapped args condition code produces the same result as swapping x and y.
    pub fn swapArgs(self: IntCC) IntCC {
        return switch (self) {
            .eq => .eq,
            .ne => .ne,
            .sgt => .slt,
            .sge => .sle,
            .slt => .sgt,
            .sle => .sge,
            .ugt => .ult,
            .uge => .ule,
            .ult => .ugt,
            .ule => .uge,
        };
    }

    /// Get the corresponding IntCC with the equal component removed.
    pub fn withoutEqual(self: IntCC) IntCC {
        return switch (self) {
            .sgt, .sge => .sgt,
            .slt, .sle => .slt,
            .ugt, .uge => .ugt,
            .ult, .ule => .ult,
            else => self,
        };
    }

    /// Get the corresponding unsigned condition code.
    pub fn unsigned(self: IntCC) IntCC {
        return switch (self) {
            .sgt, .ugt => .ugt,
            .sge, .uge => .uge,
            .slt, .ult => .ult,
            .sle, .ule => .ule,
            else => self,
        };
    }
};

/// Condition code for comparing floating point numbers.
///
/// Used by the fcmp instruction to compare floating point values.
/// Handles IEEE floating point special cases including NaN.
pub const FloatCC = enum(u8) {
    /// EQ | LT | GT (ordered)
    ord,
    /// UN (unordered - either value is NaN)
    uno,
    /// EQ
    eq,
    /// UN | LT | GT (not equal)
    ne,
    /// LT | GT (ordered not equal)
    one,
    /// UN | EQ
    ueq,
    /// LT
    lt,
    /// LT | EQ
    le,
    /// GT
    gt,
    /// GT | EQ
    ge,
    /// UN | LT
    ult,
    /// UN | LT | EQ
    ule,
    /// UN | GT
    ugt,
    /// UN | GT | EQ
    uge,

    /// Get the complemented condition code.
    pub fn complement(self: FloatCC) FloatCC {
        return switch (self) {
            .ord => .uno,
            .uno => .ord,
            .eq => .ne,
            .ne => .eq,
            .one => .ueq,
            .ueq => .one,
            .lt => .uge,
            .le => .ugt,
            .gt => .ule,
            .ge => .ult,
            .ult => .ge,
            .ule => .gt,
            .ugt => .le,
            .uge => .lt,
        };
    }

    /// Get the swapped args condition code.
    pub fn swapArgs(self: FloatCC) FloatCC {
        return switch (self) {
            .ord => .ord,
            .uno => .uno,
            .eq => .eq,
            .ne => .ne,
            .one => .one,
            .ueq => .ueq,
            .lt => .gt,
            .le => .ge,
            .gt => .lt,
            .ge => .le,
            .ult => .ugt,
            .ule => .uge,
            .ugt => .ult,
            .uge => .ule,
        };
    }
};

// Tests
const testing = std.testing;

test "IntCC complement" {
    try testing.expectEqual(IntCC.ne, IntCC.eq.complement());
    try testing.expectEqual(IntCC.eq, IntCC.ne.complement());
    try testing.expectEqual(IntCC.sge, IntCC.slt.complement());
    try testing.expectEqual(IntCC.uge, IntCC.ult.complement());
}

test "IntCC swapArgs" {
    try testing.expectEqual(IntCC.eq, IntCC.eq.swapArgs());
    try testing.expectEqual(IntCC.slt, IntCC.sgt.swapArgs());
    try testing.expectEqual(IntCC.sgt, IntCC.slt.swapArgs());
    try testing.expectEqual(IntCC.ult, IntCC.ugt.swapArgs());
}

test "IntCC withoutEqual" {
    try testing.expectEqual(IntCC.sgt, IntCC.sge.withoutEqual());
    try testing.expectEqual(IntCC.slt, IntCC.sle.withoutEqual());
    try testing.expectEqual(IntCC.eq, IntCC.eq.withoutEqual());
}

test "IntCC unsigned" {
    try testing.expectEqual(IntCC.ugt, IntCC.sgt.unsigned());
    try testing.expectEqual(IntCC.uge, IntCC.sge.unsigned());
    try testing.expectEqual(IntCC.eq, IntCC.eq.unsigned());
}

test "FloatCC complement" {
    try testing.expectEqual(FloatCC.uno, FloatCC.ord.complement());
    try testing.expectEqual(FloatCC.ne, FloatCC.eq.complement());
    try testing.expectEqual(FloatCC.uge, FloatCC.lt.complement());
}

test "FloatCC swapArgs" {
    try testing.expectEqual(FloatCC.eq, FloatCC.eq.swapArgs());
    try testing.expectEqual(FloatCC.gt, FloatCC.lt.swapArgs());
    try testing.expectEqual(FloatCC.ugt, FloatCC.ult.swapArgs());
}
