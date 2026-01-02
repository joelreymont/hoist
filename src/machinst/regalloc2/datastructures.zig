const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// Sparse set for fast membership testing and iteration.
/// Maintains a dense array of elements and a sparse index.
pub fn SparseSet(comptime T: type) type {
    return struct {
        /// Dense array of elements.
        dense: std.ArrayList(T),
        /// Sparse index mapping element to dense position.
        sparse: std.AutoHashMap(T, usize),
        allocator: Allocator,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return .{
                .dense = std.ArrayList(T).init(allocator),
                .sparse = std.AutoHashMap(T, usize).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.dense.deinit();
            self.sparse.deinit();
        }

        pub fn insert(self: *Self, value: T) !void {
            if (self.sparse.contains(value)) return;

            const pos = self.dense.items.len;
            try self.dense.append(value);
            try self.sparse.put(value, pos);
        }

        pub fn remove(self: *Self, value: T) void {
            const pos = self.sparse.get(value) orelse return;

            // Swap with last element
            const last = self.dense.items.len - 1;
            if (pos != last) {
                const last_val = self.dense.items[last];
                self.dense.items[pos] = last_val;
                self.sparse.put(last_val, pos) catch {};
            }

            _ = self.dense.pop();
            _ = self.sparse.remove(value);
        }

        pub fn contains(self: *const Self, value: T) bool {
            return self.sparse.contains(value);
        }

        pub fn clear(self: *Self) void {
            self.dense.clearRetainingCapacity();
            self.sparse.clearRetainingCapacity();
        }

        pub fn items(self: *const Self) []const T {
            return self.dense.items;
        }
    };
}

/// Interval tree for range queries.
pub const IntervalTree = struct {
    intervals: std.ArrayList(Interval),
    allocator: Allocator,

    pub const Interval = struct {
        start: u32,
        end: u32,
        data: usize,

        pub fn overlaps(self: Interval, other: Interval) bool {
            return self.start < other.end and other.start < self.end;
        }
    };

    pub fn init(allocator: Allocator) IntervalTree {
        return .{
            .intervals = std.ArrayList(Interval).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *IntervalTree) void {
        self.intervals.deinit();
    }

    pub fn insert(self: *IntervalTree, start: u32, end: u32, data: usize) !void {
        try self.intervals.append(.{
            .start = start,
            .end = end,
            .data = data,
        });
    }

    pub fn query(self: *const IntervalTree, start: u32, end: u32, result: *std.ArrayList(usize)) !void {
        const query_interval = Interval{ .start = start, .end = end, .data = 0 };
        for (self.intervals.items) |interval| {
            if (interval.overlaps(query_interval)) {
                try result.append(interval.data);
            }
        }
    }
};

/// Bit set for tracking register allocation.
pub const BitSet = struct {
    bits: std.DynamicBitSetUnmanaged,
    allocator: Allocator,

    pub fn init(allocator: Allocator, size: usize) !BitSet {
        const bits = try std.DynamicBitSetUnmanaged.initEmpty(allocator, size);
        return .{
            .bits = bits,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BitSet) void {
        self.bits.deinit(self.allocator);
    }

    pub fn set(self: *BitSet, index: usize) void {
        self.bits.set(index);
    }

    pub fn unset(self: *BitSet, index: usize) void {
        self.bits.unset(index);
    }

    pub fn isSet(self: *const BitSet, index: usize) bool {
        return self.bits.isSet(index);
    }

    pub fn setAll(self: *BitSet) void {
        self.bits.setRangeValue(.{ .start = 0, .end = self.bits.capacity() }, true);
    }

    pub fn clearAll(self: *BitSet) void {
        self.bits.setRangeValue(.{ .start = 0, .end = self.bits.capacity() }, false);
    }
};

test "SparseSet insert and contains" {
    var set = SparseSet(u32).init(testing.allocator);
    defer set.deinit();

    try set.insert(5);
    try set.insert(10);
    try set.insert(15);

    try testing.expect(set.contains(5));
    try testing.expect(set.contains(10));
    try testing.expect(set.contains(15));
    try testing.expect(!set.contains(20));
}

test "SparseSet remove" {
    var set = SparseSet(u32).init(testing.allocator);
    defer set.deinit();

    try set.insert(1);
    try set.insert(2);
    try set.insert(3);

    set.remove(2);

    try testing.expect(set.contains(1));
    try testing.expect(!set.contains(2));
    try testing.expect(set.contains(3));
}

test "IntervalTree query overlaps" {
    var tree = IntervalTree.init(testing.allocator);
    defer tree.deinit();

    try tree.insert(0, 10, 0);
    try tree.insert(5, 15, 1);
    try tree.insert(20, 30, 2);

    var result = std.ArrayList(usize).init(testing.allocator);
    defer result.deinit();

    try tree.query(8, 12, &result);

    try testing.expectEqual(@as(usize, 2), result.items.len);
    try testing.expect(std.mem.indexOfScalar(usize, result.items, 0) != null);
    try testing.expect(std.mem.indexOfScalar(usize, result.items, 1) != null);
}

test "BitSet operations" {
    var bitset = try BitSet.init(testing.allocator, 64);
    defer bitset.deinit();

    bitset.set(5);
    bitset.set(10);

    try testing.expect(bitset.isSet(5));
    try testing.expect(bitset.isSet(10));
    try testing.expect(!bitset.isSet(15));

    bitset.unset(5);
    try testing.expect(!bitset.isSet(5));
}
