//! Compact representation of Option<T> for types with a reserved value.
//!
//! Ported from cranelift-entity packed_option.rs.
//! Small entity references can use a reserved value to represent None,
//! avoiding the size overhead of a full Optional.

const std = @import("std");

/// Types that have a reserved value which can't be created any other way.
pub fn ReservedValue(comptime T: type) type {
    return struct {
        /// Create an instance of the reserved value.
        pub fn reservedValue() T {
            return T.reservedValue();
        }

        /// Check whether value is the reserved one.
        pub fn isReservedValue(self: T) bool {
            return T.isReservedValue(self);
        }
    };
}

/// Packed representation of ?T.
///
/// This is a wrapper around a T, using T.reservedValue() to represent null.
pub fn PackedOption(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        /// Returns true if the packed option is null.
        pub fn isNone(self: Self) bool {
            return T.isReservedValue(self.value);
        }

        /// Returns true if the packed option is non-null.
        pub fn isSome(self: Self) bool {
            return !T.isReservedValue(self.value);
        }

        /// Expand the packed option into a normal optional.
        pub fn expand(self: Self) ?T {
            if (self.isNone()) {
                return null;
            }
            return self.value;
        }

        /// Unwrap a packed Some value or panic.
        pub fn unwrap(self: Self) T {
            return self.expand() orelse @panic("unwrap on None");
        }

        /// Unwrap a packed Some value or panic with message.
        pub fn expect(self: Self, msg: []const u8) T {
            return self.expand() orelse @panic(msg);
        }

        /// Takes the value out of the packed option, leaving None in its place.
        pub fn take(self: *Self) ?T {
            const result = self.expand();
            self.* = Self.none();
            return result;
        }

        /// Create a None value.
        pub fn none() Self {
            return .{ .value = T.reservedValue() };
        }

        /// Create a Some value.
        pub fn some(value: T) Self {
            std.debug.assert(!T.isReservedValue(value), "Can't make a PackedOption from the reserved value");
            return .{ .value = value };
        }

        /// Create from optional.
        pub fn fromOptional(opt: ?T) Self {
            return if (opt) |v| Self.some(v) else Self.none();
        }
    };
}

const testing = std.testing;

// Test entity type with reserved value
const TestEntity = struct {
    index: u32,

    const RESERVED: u32 = std.math.maxInt(u32);

    pub fn fromIndex(i: u32) TestEntity {
        std.debug.assert(i != RESERVED, "Can't use reserved index");
        return .{ .index = i };
    }

    pub fn reservedValue() TestEntity {
        return .{ .index = RESERVED };
    }

    pub fn isReservedValue(self: TestEntity) bool {
        return self.index == RESERVED;
    }

    pub fn eql(self: TestEntity, other: TestEntity) bool {
        return self.index == other.index;
    }
};

test "PackedOption basic" {
    const Opt = PackedOption(TestEntity);

    const none_val = Opt.none();
    try testing.expect(none_val.isNone());
    try testing.expect(!none_val.isSome());

    const some_val = Opt.some(TestEntity.fromIndex(42));
    try testing.expect(some_val.isSome());
    try testing.expect(!some_val.isNone());

    const expanded = some_val.expand().?;
    try testing.expect(expanded.eql(TestEntity.fromIndex(42)));
}

test "PackedOption from optional" {
    const Opt = PackedOption(TestEntity);

    const from_null = Opt.fromOptional(null);
    try testing.expect(from_null.isNone());

    const from_some = Opt.fromOptional(TestEntity.fromIndex(10));
    try testing.expect(from_some.isSome());
    try testing.expect(from_some.unwrap().eql(TestEntity.fromIndex(10)));
}

test "PackedOption take" {
    const Opt = PackedOption(TestEntity);

    var opt = Opt.some(TestEntity.fromIndex(5));
    const taken = opt.take().?;
    try testing.expect(taken.eql(TestEntity.fromIndex(5)));
    try testing.expect(opt.isNone());

    const taken_again = opt.take();
    try testing.expectEqual(@as(?TestEntity, null), taken_again);
}
