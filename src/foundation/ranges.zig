//! The `Ranges` type stores a list of contiguous index ranges that
//! span some other list's full length.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A list of contiguous index ranges.
pub const Ranges = struct {
    ranges: std.ArrayList(u32),
    reverse: bool,

    const Self = @This();

    /// Constructs a new, empty, list of ranges with at least the
    /// specified capacity.
    pub fn withCapacity(allocator: Allocator, capacity: usize) !Self {
        var ranges = std.ArrayList(u32).init(allocator);
        try ranges.ensureTotalCapacity(capacity + 1);
        return .{
            .ranges = ranges,
            .reverse = false,
        };
    }

    pub fn init(allocator: Allocator) Self {
        return .{
            .ranges = std.ArrayList(u32).init(allocator),
            .reverse = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.ranges.deinit();
    }

    /// Add a new range which begins at the end of the previous range
    /// and ends at the specified offset, exclusive.
    pub fn pushEnd(self: *Self, allocator: Allocator, end: usize) !void {
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
    pub fn len(self: *const Self) usize {
        return self.ranges.items.len -| 1;
    }

    /// Reserves capacity for at least `additional` more ranges to be
    /// added to this list.
    pub fn reserve(self: *Self, allocator: Allocator, additional: usize) !void {
        var needed = additional;
        if (needed > 0 and self.ranges.items.len == 0) {
            needed = needed +| 1;
        }
        try self.ranges.ensureUnusedCapacity(allocator, needed);
    }

    /// Get the range at the specified index.
    pub fn get(self: *const Self, index: usize) std.meta.Tuple(&.{ usize, usize }) {
        const length = self.len();
        std.debug.assert(index < length);
        const mapped_index = self.mapIndex(index);
        return .{
            @as(usize, self.ranges.items[mapped_index]),
            @as(usize, self.ranges.items[mapped_index + 1]),
        };
    }

    /// Iterator over ranges paired with their indices.
    pub const Iterator = struct {
        ranges: *const Ranges,
        pos: usize,
        rev_pos: usize,

        pub fn next(self: *Iterator) ?struct { usize, usize, usize } {
            if (self.pos < self.rev_pos) {
                const index = self.pos;
                const mapped = self.ranges.mapIndex(index);
                const start = self.ranges.ranges.items[mapped];
                const end = self.ranges.ranges.items[mapped + 1];
                self.pos += 1;
                return .{ self.ranges.mapIndex(index), start, end };
            }
            return null;
        }

        pub fn nextBack(self: *Iterator) ?struct { usize, usize, usize } {
            if (self.rev_pos > self.pos) {
                self.rev_pos -= 1;
                const index = self.rev_pos;
                const mapped = self.ranges.mapIndex(index);
                const start = self.ranges.ranges.items[mapped];
                const end = self.ranges.ranges.items[mapped + 1];
                return .{ self.ranges.mapIndex(index), start, end };
            }
            return null;
        }
    };

    /// Visit ranges in unspecified order, paired with the index each
    /// range occurs at.
    pub fn iter(self: *const Self) Iterator {
        const length = self.len();
        return .{
            .ranges = self,
            .pos = 0,
            .rev_pos = length,
        };
    }

    /// Reverse this list of ranges, so that the first range is at the
    /// last index and the last range is at the first index.
    ///
    /// Example:
    /// ```
    /// var ranges = Ranges.init(allocator);
    /// try ranges.pushEnd(allocator, 4);
    /// try ranges.pushEnd(allocator, 6);
    /// ranges.reverseIndex();
    /// // ranges.get(0) == (4, 6)
    /// // ranges.get(1) == (0, 4)
    /// ```
    pub fn reverseIndex(self: *Self) void {
        // We can't easily change the order of the endpoints in
        // self.ranges: they need to be in ascending order or our
        // compressed representation gets complicated. So instead we
        // change our interpretation of indexes using mapIndex below,
        // controlled by a simple flag. As a bonus, reversing the list
        // is constant-time!
        self.reverse = !self.reverse;
    }

    fn mapIndex(self: *const Self, index: usize) usize {
        if (self.reverse) {
            // These subtractions can't overflow because callers
            // enforce that 0 <= index < self.len()
            return self.len() - 1 - index;
        } else {
            return index;
        }
    }

    /// Update these ranges to reflect that the list they refer to has
    /// been reversed. Afterwards, the ranges will still be indexed
    /// in the same order, but the first range will refer to the
    /// same-length range at the end of the target list instead of at
    /// the beginning, and subsequent ranges will proceed backwards
    /// from there.
    ///
    /// Example:
    /// ```
    /// var ranges = Ranges.init(allocator);
    /// try ranges.pushEnd(allocator, 4);
    /// try ranges.pushEnd(allocator, 6);
    /// ranges.reverseTarget(6);
    /// // ranges.get(0) == (2, 6)
    /// // ranges.get(1) == (0, 2)
    /// ```
    pub fn reverseTarget(self: *Self, target_len: usize) void {
        const target_len_u32: u32 = @intCast(target_len);
        // The last endpoint added should be the same as the current
        // length of the target list.
        std.debug.assert(target_len_u32 == (self.ranges.getLast() orelse 0));
        for (self.ranges.items) |*end| {
            end.* = target_len_u32 - end.*;
        }
        // Put the endpoints back in ascending order, but that means
        // now our indexes are backwards.
        std.mem.reverse(u32, self.ranges.items);
        self.reverseIndex();
    }
};
