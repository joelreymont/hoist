//! Double-ended iterators over entity references and entities.
//!
//! Ported from cranelift-entity iter.rs.
//! Provides iterators for entity maps that yield (key, value) pairs.

const EntityRef = @import("entity.zig").EntityRef;

/// Iterate over all keys and values in order.
pub fn Iter(comptime K: type, comptime V: type) type {
    return struct {
        items: []const V,
        pos: usize,
        rev_pos: usize,

        const Self = @This();

        /// Create an Iter iterator over a slice.
        pub fn new(items: []const V) Self {
            return .{
                .items = items,
                .pos = 0,
                .rev_pos = items.len,
            };
        }

        /// Get the next (key, value) pair.
        pub fn next(self: *Self) ?struct { K, *const V } {
            if (self.pos < self.rev_pos) {
                const k = K.fromIndex(self.pos);
                const v = &self.items[self.pos];
                self.pos += 1;
                return .{ k, v };
            }
            return null;
        }

        /// Get the next (key, value) pair from the back.
        pub fn nextBack(self: *Self) ?struct { K, *const V } {
            if (self.rev_pos > self.pos) {
                const k = K.fromIndex(self.rev_pos - 1);
                const v = &self.items[self.rev_pos - 1];
                self.rev_pos -= 1;
                return .{ k, v };
            }
            return null;
        }

        /// Get the remaining length.
        pub fn len(self: *const Self) usize {
            return self.rev_pos - self.pos;
        }
    };
}

/// Iterate over all keys and mutable values in order.
pub fn IterMut(comptime K: type, comptime V: type) type {
    return struct {
        items: []V,
        pos: usize,
        rev_pos: usize,

        const Self = @This();

        /// Create an IterMut iterator over a mutable slice.
        pub fn new(items: []V) Self {
            return .{
                .items = items,
                .pos = 0,
                .rev_pos = items.len,
            };
        }

        /// Get the next (key, mutable value) pair.
        pub fn next(self: *Self) ?struct { K, *V } {
            if (self.pos < self.rev_pos) {
                const k = K.fromIndex(self.pos);
                const v = &self.items[self.pos];
                self.pos += 1;
                return .{ k, v };
            }
            return null;
        }

        /// Get the next (key, mutable value) pair from the back.
        pub fn nextBack(self: *Self) ?struct { K, *V } {
            if (self.rev_pos > self.pos) {
                const k = K.fromIndex(self.rev_pos - 1);
                const v = &self.items[self.rev_pos - 1];
                self.rev_pos -= 1;
                return .{ k, v };
            }
            return null;
        }

        /// Get the remaining length.
        pub fn len(self: *const Self) usize {
            return self.rev_pos - self.pos;
        }
    };
}

const testing = @import("std").testing;
const EntityRefImpl = @import("entity.zig").EntityRef;

test "Iter forward" {
    const TestEntity = EntityRefImpl(u32, "test");
    const items = [_]u32{ 10, 20, 30, 40, 50 };
    var iter = Iter(TestEntity, u32).new(&items);

    const pair1 = iter.next().?;
    try testing.expectEqual(TestEntity.fromIndex(0), pair1[0]);
    try testing.expectEqual(@as(u32, 10), pair1[1].*);

    const pair2 = iter.next().?;
    try testing.expectEqual(TestEntity.fromIndex(1), pair2[0]);
    try testing.expectEqual(@as(u32, 20), pair2[1].*);
}

test "IterMut" {
    const TestEntity = EntityRefImpl(u32, "test");
    var items = [_]u32{ 10, 20, 30 };
    var iter = IterMut(TestEntity, u32).new(&items);

    const pair1 = iter.next().?;
    pair1[1].* = 100;
    try testing.expectEqual(@as(u32, 100), items[0]);

    const pair2 = iter.nextBack().?;
    pair2[1].* = 300;
    try testing.expectEqual(@as(u32, 300), items[2]);
}
