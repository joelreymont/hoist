//! Memory operation flags.
//!
//! Flags for load/store operations that enable optimizations.
//! Ported from cranelift-codegen memflags.rs.

const std = @import("std");
const TrapCode = @import("trapcode.zig").TrapCode;

/// Endianness of a memory access.
pub const Endianness = enum {
    little,
    big,
};

/// Disjoint region of aliasing memory.
pub const AliasRegion = enum(u8) {
    heap = 0b01,
    table = 0b10,
    vmctx = 0b11,
};

/// Flags for memory operations like load/store.
///
/// Bit layout in u16:
/// - 0: aligned flag
/// - 1: readonly flag
/// - 2: little endian flag
/// - 3: big endian flag
/// - 4: checked flag
/// - 5-6: alias region
/// - 7-14: trap code
/// - 15: can_move flag
pub const MemFlags = packed struct {
    bits: u16 = 0,

    const BIT_ALIGNED: u16 = 1 << 0;
    const BIT_READONLY: u16 = 1 << 1;
    const BIT_LITTLE_ENDIAN: u16 = 1 << 2;
    const BIT_BIG_ENDIAN: u16 = 1 << 3;
    const BIT_CHECKED: u16 = 1 << 4;
    const BITS_ALIAS_REGION: u16 = 0b11 << 5;
    const BITS_TRAP_CODE: u16 = 0xFF << 7;
    const BIT_CAN_MOVE: u16 = 1 << 15;

    /// Create default flags.
    pub fn new() MemFlags {
        return .{};
    }

    /// Create flags with aligned bit set.
    pub fn trusted() MemFlags {
        return .{ .bits = BIT_ALIGNED | BIT_READONLY };
    }

    /// Set the aligned flag.
    pub fn withAligned(self: MemFlags) MemFlags {
        return .{ .bits = self.bits | BIT_ALIGNED };
    }

    /// Check if aligned flag is set.
    pub fn aligned(self: MemFlags) bool {
        return (self.bits & BIT_ALIGNED) != 0;
    }

    /// Set the readonly flag.
    pub fn withReadonly(self: MemFlags) MemFlags {
        return .{ .bits = self.bits | BIT_READONLY };
    }

    /// Check if readonly flag is set.
    pub fn readonly(self: MemFlags) bool {
        return (self.bits & BIT_READONLY) != 0;
    }

    /// Set endianness.
    pub fn withEndianness(self: MemFlags, endian: Endianness) MemFlags {
        const cleared = self.bits & ~(BIT_LITTLE_ENDIAN | BIT_BIG_ENDIAN);
        const bit = switch (endian) {
            .little => BIT_LITTLE_ENDIAN,
            .big => BIT_BIG_ENDIAN,
        };
        return .{ .bits = cleared | bit };
    }

    /// Get endianness (null means native).
    pub fn endianness(self: MemFlags) ?Endianness {
        if ((self.bits & BIT_LITTLE_ENDIAN) != 0) return .little;
        if ((self.bits & BIT_BIG_ENDIAN) != 0) return .big;
        return null;
    }

    /// Set the checked flag.
    pub fn withChecked(self: MemFlags) MemFlags {
        return .{ .bits = self.bits | BIT_CHECKED };
    }

    /// Check if checked flag is set.
    pub fn checked(self: MemFlags) bool {
        return (self.bits & BIT_CHECKED) != 0;
    }

    /// Set alias region.
    pub fn withAliasRegion(self: MemFlags, region: ?AliasRegion) MemFlags {
        const cleared = self.bits & ~BITS_ALIAS_REGION;
        const bits = if (region) |r| (@as(u16, @intFromEnum(r)) << 5) else 0;
        return .{ .bits = cleared | bits };
    }

    /// Get alias region.
    pub fn aliasRegion(self: MemFlags) ?AliasRegion {
        const bits = (self.bits & BITS_ALIAS_REGION) >> 5;
        return switch (bits) {
            0b00 => null,
            0b01 => .heap,
            0b10 => .table,
            0b11 => .vmctx,
            else => unreachable,
        };
    }
};

// Tests
const testing = std.testing;

test "MemFlags default" {
    const flags = MemFlags.new();
    try testing.expect(!flags.aligned());
    try testing.expect(!flags.readonly());
    try testing.expect(!flags.checked());
    try testing.expectEqual(@as(?Endianness, null), flags.endianness());
    try testing.expectEqual(@as(?AliasRegion, null), flags.aliasRegion());
}

test "MemFlags aligned" {
    const flags = MemFlags.new().withAligned();
    try testing.expect(flags.aligned());
    try testing.expect(!flags.readonly());
}

test "MemFlags readonly" {
    const flags = MemFlags.new().withReadonly();
    try testing.expect(!flags.aligned());
    try testing.expect(flags.readonly());
}

test "MemFlags endianness" {
    const little = MemFlags.new().withEndianness(.little);
    try testing.expectEqual(@as(?Endianness, .little), little.endianness());

    const big = MemFlags.new().withEndianness(.big);
    try testing.expectEqual(@as(?Endianness, .big), big.endianness());
}

test "MemFlags alias region" {
    const heap = MemFlags.new().withAliasRegion(.heap);
    try testing.expectEqual(@as(?AliasRegion, .heap), heap.aliasRegion());

    const table = MemFlags.new().withAliasRegion(.table);
    try testing.expectEqual(@as(?AliasRegion, .table), table.aliasRegion());

    const vmctx = MemFlags.new().withAliasRegion(.vmctx);
    try testing.expectEqual(@as(?AliasRegion, .vmctx), vmctx.aliasRegion());
}

test "MemFlags chaining" {
    const flags = MemFlags.new()
        .withAligned()
        .withReadonly()
        .withEndianness(.little)
        .withAliasRegion(.heap);

    try testing.expect(flags.aligned());
    try testing.expect(flags.readonly());
    try testing.expectEqual(@as(?Endianness, .little), flags.endianness());
    try testing.expectEqual(@as(?AliasRegion, .heap), flags.aliasRegion());
}
