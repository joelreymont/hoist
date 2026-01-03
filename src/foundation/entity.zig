//! Entity-reference based data structures for Cranelift.
//!
//! Provides type-safe indices into dense arrays using newtype wrappers.
//! Ported from cranelift-entity, using Zig stdlib under the hood.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A type-safe index into entity collections.
/// Entities are u32 newtypes that provide compile-time type safety.
///
/// Usage:
/// ```
/// const Block = EntityRef(u32, "block");
/// const Inst = EntityRef(u32, "inst");
/// ```
pub fn EntityRef(comptime IndexType: type, comptime prefix: []const u8) type {
    return packed struct {
        const Self = @This();
        pub const Index = IndexType;

        index: IndexType,

        pub const invalid: Self = .{ .index = std.math.maxInt(IndexType) };

        pub fn new(i: usize) Self {
            std.debug.assert(i < std.math.maxInt(IndexType));
            return .{ .index = @intCast(i) };
        }

        pub fn fromRaw(raw: IndexType) Self {
            return .{ .index = raw };
        }

        pub fn fromBits(raw: IndexType) Self {
            return Self.fromRaw(raw);
        }

        pub fn fromU32(raw: IndexType) Self {
            return Self.fromRaw(raw);
        }

        pub fn toIndex(self: Self) usize {
            return @intCast(self.index);
        }

        pub fn toRaw(self: Self) IndexType {
            return self.index;
        }

        pub fn asBits(self: Self) IndexType {
            return self.toRaw();
        }

        pub fn asU32(self: Self) IndexType {
            return self.toRaw();
        }

        pub fn isValid(self: Self) bool {
            return self.index != std.math.maxInt(IndexType);
        }

        pub fn format(self: Self, writer: anytype) !void {
            try writer.print("{s}{d}", .{ prefix, self.index });
        }
    };
}

/// Primary map: allocates new entity references and stores associated values.
/// Only one PrimaryMap should exist per entity type.
pub fn PrimaryMap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        items: std.ArrayList(V),

        pub fn init(_: Allocator) Self {
            return .{ .items = .{} };
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.items.deinit(allocator);
        }

        pub fn push(self: *Self, allocator: Allocator, value: V) !K {
            const key = self.nextKey();
            try self.items.append(allocator, value);
            return key;
        }

        pub fn nextKey(self: *const Self) K {
            return K.new(self.items.items.len);
        }

        pub fn get(self: *const Self, key: K) ?*const V {
            const idx = key.toIndex();
            if (idx >= self.items.items.len) return null;
            return &self.items.items[idx];
        }

        pub fn getMut(self: *Self, key: K) ?*V {
            const idx = key.toIndex();
            if (idx >= self.items.items.len) return null;
            return &self.items.items[idx];
        }

        pub fn set(self: *Self, allocator: Allocator, key: K, value: V) !void {
            const idx = key.toIndex();
            if (idx >= self.items.items.len) {
                try self.items.resize(allocator, idx + 1);
            }
            self.items.items[idx] = value;
        }

        pub fn getAssert(self: *const Self, key: K) *const V {
            return &self.items.items[key.toIndex()];
        }

        pub fn getMutAssert(self: *Self, key: K) *V {
            return &self.items.items[key.toIndex()];
        }

        pub fn set(self: *Self, allocator: Allocator, key: K, value: V) !void {
            const idx = key.toIndex();
            if (idx >= self.items.items.len) {
                try self.items.resize(allocator, idx + 1);
            }
            self.items.items[idx] = value;
        }

        pub fn isValid(self: *const Self, key: K) bool {
            return key.toIndex() < self.items.items.len;
        }

        pub fn len(self: *const Self) usize {
            return self.items.items.len;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.items.items.len == 0;
        }

        pub fn clear(self: *Self) void {
            self.items.clearRetainingCapacity();
        }

        pub fn values(self: *const Self) []const V {
            return self.items.items;
        }

        pub fn valuesMut(self: *Self) []V {
            return self.items.items;
        }

        /// Iterator over (key, value) pairs.
        pub fn iter(self: *const Self) KeyValueIterator(K, V, false) {
            return .{ .slice = self.items.items, .pos = 0 };
        }

        pub fn iterMut(self: *Self) KeyValueIterator(K, V, true) {
            return .{ .slice = self.items.items, .pos = 0 };
        }

        /// Iterator over keys only.
        pub fn keys(self: *const Self) Keys(K) {
            return Keys(K).init(self.items.items.len);
        }
    };
}

/// Secondary map: associates additional data with entities allocated elsewhere.
/// Auto-grows and returns default value for missing entries.
pub fn SecondaryMap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        items: std.ArrayList(V),
        default: V,

        pub fn init(_allocator: Allocator, default: V) Self {
            _ = _allocator;
            return .{
                .items = std.ArrayList(V){},
                .default = default,
            };
        }

        pub fn initDefault(allocator: Allocator) Self {
            return init(allocator, std.mem.zeroes(V));
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.items.deinit(allocator);
        }

        pub fn get(self: *const Self, key: K) V {
            const idx = key.toIndex();
            if (idx >= self.items.items.len) return self.default;
            return self.items.items[idx];
        }

        pub fn getPtr(self: *const Self, key: K) ?*const V {
            const idx = key.toIndex();
            if (idx >= self.items.items.len) return null;
            return &self.items.items[idx];
        }

        pub fn set(self: *Self, allocator: Allocator, key: K, value: V) !void {
            const idx = key.toIndex();
            try self.ensureCapacity(allocator, idx + 1);
            self.items.items[idx] = value;
        }

        fn ensureCapacity(self: *Self, allocator: Allocator, new_len: usize) !void {
            if (new_len <= self.items.items.len) return;
            const old_len = self.items.items.len;
            try self.items.resize(allocator, new_len);
            @memset(self.items.items[old_len..new_len], self.default);
        }

        pub fn clear(self: *Self) void {
            self.items.clearRetainingCapacity();
        }

        pub fn resize(self: *Self, allocator: Allocator, n: usize) !void {
            try self.ensureCapacity(allocator, n);
        }

        pub fn len(self: *const Self) usize {
            return self.items.items.len;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.items.items.len == 0;
        }

        pub fn values(self: *const Self) []const V {
            return self.items.items;
        }

        pub fn valuesMut(self: *Self) []V {
            return self.items.items;
        }

        pub fn keys(self: *const Self) Keys(K) {
            return Keys(K).init(self.items.items.len);
        }
    };
}

/// Entity set: tracks membership using a bitset.
pub fn EntitySet(comptime K: type) type {
    return struct {
        const Self = @This();

        bitset: std.DynamicBitSet,

        pub fn init(allocator: Allocator) Self {
            return .{ .bitset = std.DynamicBitSet.initEmpty(allocator, 0) catch unreachable };
        }

        pub fn initWithCapacity(allocator: Allocator, capacity: usize) !Self {
            return .{ .bitset = try std.DynamicBitSet.initEmpty(allocator, capacity) };
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            _ = allocator;
            self.bitset.deinit();
        }

        pub fn insert(self: *Self, key: K) !bool {
            const idx = key.toIndex();
            if (idx >= self.bitset.capacity()) {
                try self.bitset.resize(idx + 1, false);
            }
            const was_set = self.bitset.isSet(idx);
            self.bitset.set(idx);
            return !was_set;
        }

        pub fn remove(self: *Self, key: K) bool {
            const idx = key.toIndex();
            if (idx >= self.bitset.capacity()) return false;
            const was_set = self.bitset.isSet(idx);
            self.bitset.unset(idx);
            return was_set;
        }

        pub fn contains(self: *const Self, key: K) bool {
            const idx = key.toIndex();
            if (idx >= self.bitset.capacity()) return false;
            return self.bitset.isSet(idx);
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.bitset.count() == 0;
        }

        pub fn count(self: *const Self) usize {
            return self.bitset.count();
        }

        pub fn clear(self: *Self) void {
            self.bitset.setRangeValue(.{ .start = 0, .end = self.bitset.capacity() }, false);
        }

        /// Returns an iterator over set entity keys.
        pub fn iter(self: *const Self) SetIterator(K) {
            return .{ .inner = self.bitset.iterator(.{}) };
        }

        pub fn pop(self: *Self) ?K {
            // Find highest set bit
            var i = self.bitset.capacity();
            while (i > 0) {
                i -= 1;
                if (self.bitset.isSet(i)) {
                    self.bitset.unset(i);
                    return K.new(i);
                }
            }
            return null;
        }
    };
}

/// Iterator over entity keys.
pub fn Keys(comptime K: type) type {
    return struct {
        const Self = @This();

        pos: usize,
        end: usize,

        pub fn init(length: usize) Self {
            return .{ .pos = 0, .end = length };
        }

        pub fn next(self: *Self) ?K {
            if (self.pos >= self.end) return null;
            const key = K.new(self.pos);
            self.pos += 1;
            return key;
        }

        pub fn nextBack(self: *Self) ?K {
            if (self.end <= self.pos) return null;
            self.end -= 1;
            return K.new(self.end);
        }

        pub fn len(self: *const Self) usize {
            return self.end - self.pos;
        }
    };
}

/// Iterator over (key, value) pairs.
pub fn KeyValueIterator(comptime K: type, comptime V: type, comptime mutable: bool) type {
    const SliceType = if (mutable) []V else []const V;
    const PtrType = if (mutable) *V else *const V;

    return struct {
        const Self = @This();

        slice: SliceType,
        pos: usize,

        pub fn next(self: *Self) ?struct { key: K, value: PtrType } {
            if (self.pos >= self.slice.len) return null;
            const key = K.new(self.pos);
            const value = &self.slice[self.pos];
            self.pos += 1;
            return .{ .key = key, .value = value };
        }
    };
}

/// Iterator over set elements.
pub fn SetIterator(comptime K: type) type {
    return struct {
        const Self = @This();

        inner: std.DynamicBitSet.Iterator(.{}),

        pub fn next(self: *Self) ?K {
            const idx = self.inner.next() orelse return null;
            return K.new(idx);
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "EntityRef basic" {
    const Block = EntityRef(u32, "block");

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b42 = Block.new(42);

    try std.testing.expectEqual(@as(usize, 0), b0.toIndex());
    try std.testing.expectEqual(@as(usize, 1), b1.toIndex());
    try std.testing.expectEqual(@as(usize, 42), b42.toIndex());

    try std.testing.expect(b0.isValid());
    try std.testing.expect(!Block.invalid.isValid());
}

test "EntityRef format" {
    const Block = EntityRef(u32, "block");
    const b42 = Block.new(42);

    var buf: [32]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{}", .{b42}) catch unreachable;
    try std.testing.expectEqualStrings("block42", result);
}

test "PrimaryMap basic" {
    const Block = EntityRef(u32, "block");
    var map = PrimaryMap(Block, i32).init(std.testing.allocator);
    defer map.deinit(std.testing.allocator);

    try std.testing.expect(map.isEmpty());

    const k0 = try map.push(std.testing.allocator, 12);
    const k1 = try map.push(std.testing.allocator, 33);

    try std.testing.expectEqual(@as(usize, 0), k0.toIndex());
    try std.testing.expectEqual(@as(usize, 1), k1.toIndex());
    try std.testing.expectEqual(@as(i32, 12), map.getAssert(k0).*);
    try std.testing.expectEqual(@as(i32, 33), map.getAssert(k1).*);
    try std.testing.expectEqual(@as(usize, 2), map.len());
}

test "PrimaryMap keys iterator" {
    const Block = EntityRef(u32, "block");
    var map = PrimaryMap(Block, i32).init(std.testing.allocator);
    defer map.deinit(std.testing.allocator);

    _ = try map.push(std.testing.allocator, 12);
    _ = try map.push(std.testing.allocator, 33);

    var keys = map.keys();
    try std.testing.expectEqual(@as(usize, 0), keys.next().?.toIndex());
    try std.testing.expectEqual(@as(usize, 1), keys.next().?.toIndex());
    try std.testing.expect(keys.next() == null);
}

test "SecondaryMap basic" {
    const Block = EntityRef(u32, "block");
    var map = SecondaryMap(Block, i32).init(std.testing.allocator, 0);
    defer map.deinit(std.testing.allocator);

    const r0 = Block.new(0);
    const r1 = Block.new(1);
    const r2 = Block.new(2);

    // Should return default for unset keys
    try std.testing.expectEqual(@as(i32, 0), map.get(r0));
    try std.testing.expectEqual(@as(i32, 0), map.get(r2));

    try map.set(std.testing.allocator, r2, 3);
    try map.set(std.testing.allocator, r1, 5);

    try std.testing.expectEqual(@as(i32, 0), map.get(r0));
    try std.testing.expectEqual(@as(i32, 5), map.get(r1));
    try std.testing.expectEqual(@as(i32, 3), map.get(r2));
}

test "EntitySet basic" {
    const Block = EntityRef(u32, "block");
    var set = EntitySet(Block).init(std.testing.allocator);
    defer set.deinit(std.testing.allocator);

    const r0 = Block.new(0);
    const r1 = Block.new(1);
    const r2 = Block.new(2);

    try std.testing.expect(set.isEmpty());

    _ = try set.insert(r2);
    _ = try set.insert(r1);

    try std.testing.expect(!set.contains(r0));
    try std.testing.expect(set.contains(r1));
    try std.testing.expect(set.contains(r2));
    try std.testing.expect(!set.isEmpty());
    try std.testing.expectEqual(@as(usize, 2), set.count());
}

test "EntitySet pop" {
    const Block = EntityRef(u32, "block");
    var set = EntitySet(Block).init(std.testing.allocator);
    defer set.deinit(std.testing.allocator);

    _ = try set.insert(Block.new(0));
    _ = try set.insert(Block.new(1));
    _ = try set.insert(Block.new(2));

    // Pop should return highest first
    try std.testing.expectEqual(@as(usize, 2), set.pop().?.toIndex());
    try std.testing.expectEqual(@as(usize, 1), set.pop().?.toIndex());
    try std.testing.expectEqual(@as(usize, 0), set.pop().?.toIndex());
    try std.testing.expect(set.pop() == null);
}

test "EntitySet iter" {
    const Block = EntityRef(u32, "block");
    var set = EntitySet(Block).init(std.testing.allocator);
    defer set.deinit(std.testing.allocator);

    _ = try set.insert(Block.new(2));
    _ = try set.insert(Block.new(5));
    _ = try set.insert(Block.new(3));

    var collected: [3]usize = undefined;
    var i: usize = 0;
    var iter = set.iter();
    while (iter.next()) |k| {
        collected[i] = k.toIndex();
        i += 1;
    }

    try std.testing.expectEqual(@as(usize, 3), i);
    // Iteration order is ascending
    try std.testing.expectEqual(@as(usize, 2), collected[0]);
    try std.testing.expectEqual(@as(usize, 3), collected[1]);
    try std.testing.expectEqual(@as(usize, 5), collected[2]);
}

test "Keys reverse iteration" {
    const Block = EntityRef(u32, "block");
    var keys = Keys(Block).init(3);

    try std.testing.expectEqual(@as(usize, 2), keys.nextBack().?.toIndex());
    try std.testing.expectEqual(@as(usize, 0), keys.next().?.toIndex());
    try std.testing.expectEqual(@as(usize, 1), keys.next().?.toIndex());
    try std.testing.expect(keys.next() == null);
    try std.testing.expect(keys.nextBack() == null);
}
