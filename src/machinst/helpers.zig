//! Miscellaneous helpers for machine backends.
//!
//! Ported from cranelift-codegen machinst/helpers.rs.
//! Utility functions for ISA backends.

const Type = @import("../ir/types.zig").Type;

/// Returns the size (in bits) of a given type.
pub fn tyBits(ty: Type) usize {
    return @as(usize, ty.bits());
}

/// Align a size up to a power-of-two alignment.
pub fn alignTo(comptime T: type, x: T, alignment: T) T {
    const alignment_mask = alignment - 1;
    return (x + alignment_mask) & ~alignment_mask;
}

const testing = @import("std").testing;

test "tyBits" {
    try testing.expectEqual(@as(usize, 8), tyBits(Type.I8));
    try testing.expectEqual(@as(usize, 32), tyBits(Type.I32));
    try testing.expectEqual(@as(usize, 64), tyBits(Type.I64));
}

test "alignTo" {
    try testing.expectEqual(@as(u32, 8), alignTo(u32, 5, 8));
    try testing.expectEqual(@as(u32, 16), alignTo(u32, 9, 16));
    try testing.expectEqual(@as(u32, 16), alignTo(u32, 16, 16));
}
