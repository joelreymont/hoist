//! Bitsets for Cranelift.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn ScalarBitSet(comptime T: type) type {
    return struct {
        bits: T,

        const Self = @This();

        pub fn init() Self {
            return .{ .bits = 0 };
        }

        pub fn fromRange(lo: u8, hi: u8) Self {
            std.debug.assert(lo <= hi);
            std.debug.assert(hi <= capacity());
            const one: T = 1;
            const hi_rng = if (hi >= 1)
                (one << @intCast(hi - 1)) + ((one << @intCast(hi - 1)) - one)
            else
                0;
            const lo_rng = (one << @intCast(lo)) - one;
            return .{ .bits = hi_rng - lo_rng };
        }

        pub fn capacity() u8 {
            return @sizeOf(T) * 8;
        }

        pub fn len(self: Self) u8 {
            return @intCast(@popCount(self.bits));
        }

        pub fn isEmpty(self: Self) bool {
            return self.bits == 0;
        }

        pub fn contains(self: Self, i: u8) bool {
            std.debug.assert(i < capacity());
            return (self.bits & (@as(T, 1) << @intCast(i))) != 0;
        }

        pub fn insert(self: *Self, i: u8) bool {
            const was_new = !self.contains(i);
            self.bits |= @as(T, 1) << @intCast(i);
            return was_new;
        }

        pub fn remove(self: *Self, i: u8) bool {
            const was_present = self.contains(i);
            self.bits &= ~(@as(T, 1) << @intCast(i));
            return was_present;
        }

        pub fn clear(self: *Self) void {
            self.bits = 0;
        }

        pub fn popMin(self: *Self) ?u8 {
            const min_val = self.min() orelse return null;
            _ = self.remove(min_val);
            return min_val;
        }

        pub fn popMax(self: *Self) ?u8 {
            const max_val = self.max() orelse return null;
            _ = self.remove(max_val);
            return max_val;
        }

        pub fn min(self: Self) ?u8 {
            if (self.bits == 0) return null;
            return @intCast(@ctz(self.bits));
        }

        pub fn max(self: Self) ?u8 {
            if (self.bits == 0) return null;
            const leading_zeroes = @clz(self.bits);
            return capacity() - @as(u8, @intCast(leading_zeroes)) - 1;
        }

        pub fn iterator(self: Self) Iterator {
            return .{ .bitset = self };
        }

        pub const Iterator = struct {
            bitset: Self,

            pub fn next(self: *Iterator) ?u8 {
                return self.bitset.popMin();
            }
        };
    };
}

pub const CompoundBitSet = struct {
    elems: []ScalarBitSet(usize),
    max_elem: ?u32,
    allocator: Allocator,

    const Self = @This();
    const BITS_PER_SCALAR: usize = @sizeOf(usize) * 8;

    pub fn init(allocator: Allocator) Self {
        return .{
            .elems = &.{},
            .max_elem = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.elems);
    }

    pub fn len(self: Self) usize {
        var count: usize = 0;
        for (self.elems) |scalar| {
            count += scalar.len();
        }
        return count;
    }

    pub fn isEmpty(self: Self) bool {
        return self.len() == 0;
    }

    fn wordAndBit(i: usize) struct { word: usize, bit: u8 } {
        const word = i / BITS_PER_SCALAR;
        const bit: u8 = @intCast(i % BITS_PER_SCALAR);
        return .{ .word = word, .bit = bit };
    }

    fn elemFromWordBit(word: usize, bit: u8) usize {
        return word * BITS_PER_SCALAR + bit;
    }

    pub fn contains(self: Self, i: usize) bool {
        const wb = wordAndBit(i);
        if (wb.word >= self.elems.len) return false;
        return self.elems[wb.word].contains(wb.bit);
    }

    pub fn insert(self: *Self, i: usize) !bool {
        const wb = wordAndBit(i);
        try self.ensureCapacity(i + 1);
        const was_new = self.elems[wb.word].insert(wb.bit);
        if (was_new) {
            if (self.max_elem == null or i > self.max_elem.?) {
                self.max_elem = @intCast(i);
            }
        }
        return was_new;
    }

    pub fn remove(self: *Self, i: usize) bool {
        const wb = wordAndBit(i);
        if (wb.word >= self.elems.len) return false;
        const was_present = self.elems[wb.word].remove(wb.bit);
        if (was_present and self.max_elem != null and i == self.max_elem.?) {
            self.max_elem = self.computeMax();
        }
        return was_present;
    }

    pub fn clear(self: *Self) void {
        for (self.elems) |*scalar| {
            scalar.clear();
        }
        self.max_elem = null;
    }

    pub fn min(self: Self) ?usize {
        for (self.elems, 0..) |scalar, word| {
            if (scalar.min()) |bit| {
                return elemFromWordBit(word, bit);
            }
        }
        return null;
    }

    pub fn max(self: Self) ?usize {
        return self.max_elem;
    }

    fn computeMax(self: Self) ?u32 {
        var word = self.elems.len;
        while (word > 0) {
            word -= 1;
            if (self.elems[word].max()) |bit| {
                return @intCast(elemFromWordBit(word, bit));
            }
        }
        return null;
    }

    fn ensureCapacity(self: *Self, cap: usize) !void {
        const words_needed = (cap + BITS_PER_SCALAR - 1) / BITS_PER_SCALAR;
        if (words_needed <= self.elems.len) return;
        const new_elems = try self.allocator.realloc(self.elems, words_needed);
        for (new_elems[self.elems.len..]) |*scalar| {
            scalar.* = ScalarBitSet(usize).init();
        }
        self.elems = new_elems;
    }
};

test "ScalarBitSet basic" {
    var bitset = ScalarBitSet(u32).init();
    try std.testing.expect(bitset.isEmpty());
    try std.testing.expectEqual(@as(u8, 0), bitset.len());
    try std.testing.expect(bitset.insert(4));
    try std.testing.expect(bitset.insert(5));
    try std.testing.expect(bitset.contains(4));
    try std.testing.expect(!bitset.insert(5));
    try std.testing.expect(bitset.remove(5));
    try std.testing.expect(!bitset.contains(5));
}

test "ScalarBitSet range" {
    const bitset = ScalarBitSet(u64).fromRange(3, 6);
    try std.testing.expectEqual(@as(u8, 3), bitset.len());
    try std.testing.expect(bitset.contains(3));
    try std.testing.expect(bitset.contains(4));
    try std.testing.expect(bitset.contains(5));
    try std.testing.expect(!bitset.contains(6));
}

test "CompoundBitSet basic" {
    const allocator = std.testing.allocator;
    var bitset = CompoundBitSet.init(allocator);
    defer bitset.deinit();
    try std.testing.expect(bitset.isEmpty());
    try std.testing.expect(try bitset.insert(444));
    try std.testing.expect(bitset.contains(444));
    try std.testing.expect(bitset.remove(444));
    try std.testing.expect(!bitset.contains(444));
}
