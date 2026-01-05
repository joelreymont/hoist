//! A double-ended iterator over entity references.
//!
//! Ported from cranelift-entity keys.rs.
//! Iterates over all entity keys in order.

const std = @import("std");
const EntityRef = @import("entity.zig").EntityRef;

/// Iterate over all keys in order.
pub fn Keys(comptime K: type) type {
    return struct {
        pos: usize,
        rev_pos: usize,

        const Self = @This();

        /// Create a Keys iterator that visits `len` entities starting from 0.
        pub fn withLen(len: usize) Self {
            return .{
                .pos = 0,
                .rev_pos = len,
            };
        }

        /// Get the next key.
        pub fn next(self: *Self) ?K {
            if (self.pos < self.rev_pos) {
                const k = K.fromIndex(self.pos);
                self.pos += 1;
                return k;
            }
            return null;
        }

        /// Get the next key from the back.
        pub fn nextBack(self: *Self) ?K {
            if (self.rev_pos > self.pos) {
                const k = K.fromIndex(self.rev_pos - 1);
                self.rev_pos -= 1;
                return k;
            }
            return null;
        }

        /// Get the remaining length.
        pub fn len(self: *const Self) usize {
            return self.rev_pos - self.pos;
        }
    };
}

const testing = std.testing;

test "Keys forward iteration" {
    const TestEntity = EntityRef(u32, "test");
    var keys = Keys(TestEntity).withLen(5);

    try testing.expectEqual(@as(usize, 5), keys.len());
    try testing.expectEqual(TestEntity.fromIndex(0), keys.next().?);
    try testing.expectEqual(TestEntity.fromIndex(1), keys.next().?);
    try testing.expectEqual(TestEntity.fromIndex(2), keys.next().?);
    try testing.expectEqual(TestEntity.fromIndex(3), keys.next().?);
    try testing.expectEqual(TestEntity.fromIndex(4), keys.next().?);
    try testing.expectEqual(@as(?TestEntity, null), keys.next());
}

test "Keys backward iteration" {
    const TestEntity = EntityRef(u32, "test");
    var keys = Keys(TestEntity).withLen(5);

    try testing.expectEqual(TestEntity.fromIndex(4), keys.nextBack().?);
    try testing.expectEqual(TestEntity.fromIndex(3), keys.nextBack().?);
    try testing.expectEqual(TestEntity.fromIndex(2), keys.nextBack().?);
    try testing.expectEqual(TestEntity.fromIndex(1), keys.nextBack().?);
    try testing.expectEqual(TestEntity.fromIndex(0), keys.nextBack().?);
    try testing.expectEqual(@as(?TestEntity, null), keys.nextBack());
}

test "Keys bidirectional iteration" {
    const TestEntity = EntityRef(u32, "test");
    var keys = Keys(TestEntity).withLen(5);

    try testing.expectEqual(TestEntity.fromIndex(0), keys.next().?);
    try testing.expectEqual(TestEntity.fromIndex(4), keys.nextBack().?);
    try testing.expectEqual(TestEntity.fromIndex(1), keys.next().?);
    try testing.expectEqual(TestEntity.fromIndex(3), keys.nextBack().?);
    try testing.expectEqual(TestEntity.fromIndex(2), keys.next().?);
    try testing.expectEqual(@as(?TestEntity, null), keys.next());
    try testing.expectEqual(@as(?TestEntity, null), keys.nextBack());
}
