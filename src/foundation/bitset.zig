//! Bitset utilities for Cranelift.
//! Uses std.bit_set with minimal helpers for register allocation.

const std = @import("std");

/// Helper for register allocation: pop minimum bit from integer bitset.
pub fn popMin(comptime T: type, bits: *T) ?u8 {
    if (bits.* == 0) return null;
    const bit = @ctz(bits.*);
    bits.* &= ~(@as(T, 1) << @intCast(bit));
    return @intCast(bit);
}

/// Helper for register allocation: pop maximum bit from integer bitset.
pub fn popMax(comptime T: type, bits: *T) ?u8 {
    if (bits.* == 0) return null;
    const bit = @bitSizeOf(T) - 1 - @clz(bits.*);
    bits.* &= ~(@as(T, 1) << @intCast(bit));
    return @intCast(bit);
}

test "popMin basic" {
    var bits: u8 = 0b00101100;
    try std.testing.expectEqual(@as(?u8, 2), popMin(u8, &bits));
    try std.testing.expectEqual(@as(u8, 0b00101000), bits);
    try std.testing.expectEqual(@as(?u8, 3), popMin(u8, &bits));
    try std.testing.expectEqual(@as(u8, 0b00100000), bits);
    try std.testing.expectEqual(@as(?u8, 5), popMin(u8, &bits));
    try std.testing.expectEqual(@as(u8, 0), bits);
    try std.testing.expectEqual(@as(?u8, null), popMin(u8, &bits));
}

test "popMax basic" {
    var bits: u8 = 0b00101100;
    try std.testing.expectEqual(@as(?u8, 5), popMax(u8, &bits));
    try std.testing.expectEqual(@as(u8, 0b00001100), bits);
    try std.testing.expectEqual(@as(?u8, 3), popMax(u8, &bits));
    try std.testing.expectEqual(@as(u8, 0b00000100), bits);
    try std.testing.expectEqual(@as(?u8, 2), popMax(u8, &bits));
    try std.testing.expectEqual(@as(u8, 0), bits);
    try std.testing.expectEqual(@as(?u8, null), popMax(u8, &bits));
}
