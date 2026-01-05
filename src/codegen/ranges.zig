//! Index ranges for list slicing.
//!
//! Ported from cranelift-codegen ranges.rs.
//! The Ranges type stores a list of contiguous index ranges that span some
//! other list's full length.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A list of contiguous index ranges.
pub const Ranges = struct {
    ranges: std.ArrayList(u32),
    reverse: bool,

    pub fn init(allocator: Allocator) Ranges {
        return .{
            .ranges = std.ArrayList(u32){},
            .reverse = false,
        };
    }

    pub fn deinit(self: *Ranges, allocator: Allocator) void {
        self.ranges.deinit(allocator);
    }

    /// Constructs a new list of ranges with at least the specified capacity.
    pub fn withCapacity(allocator: Allocator, capacity: usize) !Ranges {
        var ranges = init(allocator);
        try ranges.reserve(allocator, capacity);
        return ranges;
    }

    /// Add a new range which begins at the end of the previous range
    /// and ends at the specified offset, exclusive.
    pub fn pushEnd(self: *Ranges, allocator: Allocator, end: usize) !void {
        std.debug.assert(!self.reverse);

        // To keep this implementation simple we explicitly store the
        // starting index, which is always 0, so that all ranges are
        // represented by adjacent pairs in the list. But we add it
        // lazily so that an empty list doesn't have to allocate.
        if (self.ranges.items.len == 0) {
            try self.ranges.append(allocator, 0);
        }
        try self.ranges.append(allocator, @intCast(end));
    }

    /// Number of ranges in this list.
    pub fn len(self: *const Ranges) usize {
        return if (self.ranges.items.len > 0) self.ranges.items.len - 1 else 0;
    }

    /// Reserves capacity for at least `additional` more ranges to be
    /// added to this list.
    pub fn reserve(self: *Ranges, allocator: Allocator, additional: usize) !void {
        var to_reserve = additional;
        if (additional > 0 and self.ranges.items.len == 0) {
            to_reserve = additional + 1;
        }
        try self.ranges.ensureUnusedCapacity(allocator, to_reserve);
    }

    /// Get the range at the specified index.
    pub fn get(self: *const Ranges, index: usize) struct { start: usize, end: usize } {
        const length = self.len();
        std.debug.assert(index < length);
        const mapped_index = self.mapIndex(index);
        return .{
            .start = self.ranges.items[mapped_index],
            .end = self.ranges.items[mapped_index + 1],
        };
    }

    /// Iterator over ranges.
    pub const Iterator = struct {
        ranges: *const Ranges,
        index: usize,

        pub fn next(self: *Iterator) ?struct { index: usize, start: usize, end: usize } {
            if (self.index >= self.ranges.len()) return null;
            const mapped = self.ranges.mapIndex(self.index);
            const result = .{
                .index = mapped,
                .start = self.ranges.ranges.items[self.index],
                .end = self.ranges.ranges.items[self.index + 1],
            };
            self.index += 1;
            return result;
        }
    };

    /// Visit ranges in order, paired with the index each range occurs at.
    pub fn iterator(self: *const Ranges) Iterator {
        return .{ .ranges = self, .index = 0 };
    }

    /// Reverse this list of ranges, so that the first range is at the
    /// last index and the last range is at the first index.
    pub fn reverseIndex(self: *Ranges) void {
        // We can't easily change the order of the endpoints in
        // self.ranges: they need to be in ascending order or our
        // compressed representation gets complicated. So instead we
        // change our interpretation of indexes using mapIndex,
        // controlled by a simple flag. As a bonus, reversing the list
        // is constant-time!
        self.reverse = !self.reverse;
    }

    fn mapIndex(self: *const Ranges, index: usize) usize {
        return if (self.reverse)
            // These subtractions can't overflow because callers
            // enforce that 0 <= index < self.len()
            self.len() - 1 - index
        else
            index;
    }

    /// Update these ranges to reflect that the list they refer to has
    /// been reversed. Afterwards, the ranges will still be indexed
    /// in the same order, but the first range will refer to the
    /// same-length range at the end of the target list instead of at
    /// the beginning, and subsequent ranges will proceed backwards
    /// from there.
    pub fn reverseTarget(self: *Ranges, target_len: usize) void {
        const target_len_u32: u32 = @intCast(target_len);

        // The last endpoint added should be the same as the current
        // length of the target list.
        std.debug.assert(target_len_u32 == (if (self.ranges.items.len > 0)
            self.ranges.items[self.ranges.items.len - 1]
        else
            0));

        for (self.ranges.items) |*end| {
            end.* = target_len_u32 - end.*;
        }

        // Put the endpoints back in ascending order, but that means
        // now our indexes are backwards.
        std.mem.reverse(u32, self.ranges.items);
        self.reverseIndex();
    }
};

const testing = std.testing;

test "Ranges basic" {
    var ranges = Ranges.init(testing.allocator);
    defer ranges.deinit(testing.allocator);

    try ranges.pushEnd(testing.allocator, 4);
    try ranges.pushEnd(testing.allocator, 6);

    try testing.expectEqual(@as(usize, 2), ranges.len());

    const r0 = ranges.get(0);
    try testing.expectEqual(@as(usize, 0), r0.start);
    try testing.expectEqual(@as(usize, 4), r0.end);

    const r1 = ranges.get(1);
    try testing.expectEqual(@as(usize, 4), r1.start);
    try testing.expectEqual(@as(usize, 6), r1.end);
}

test "Ranges reverse_index" {
    var ranges = Ranges.init(testing.allocator);
    defer ranges.deinit(testing.allocator);

    try ranges.pushEnd(testing.allocator, 4);
    try ranges.pushEnd(testing.allocator, 6);
    ranges.reverseIndex();

    const r0 = ranges.get(0);
    try testing.expectEqual(@as(usize, 4), r0.start);
    try testing.expectEqual(@as(usize, 6), r0.end);

    const r1 = ranges.get(1);
    try testing.expectEqual(@as(usize, 0), r1.start);
    try testing.expectEqual(@as(usize, 4), r1.end);
}

test "Ranges reverse_target" {
    var ranges = Ranges.init(testing.allocator);
    defer ranges.deinit(testing.allocator);

    try ranges.pushEnd(testing.allocator, 4);
    try ranges.pushEnd(testing.allocator, 6);
    ranges.reverseTarget(6);

    const r0 = ranges.get(0);
    try testing.expectEqual(@as(usize, 2), r0.start);
    try testing.expectEqual(@as(usize, 6), r0.end);

    const r1 = ranges.get(1);
    try testing.expectEqual(@as(usize, 0), r1.start);
    try testing.expectEqual(@as(usize, 2), r1.end);
}
