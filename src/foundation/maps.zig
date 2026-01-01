const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// Primary map K -> V using dense entity references.
///
/// Allocates new entity references with push().
/// Only one PrimaryMap per EntityRef type to avoid conflicting refs.
pub fn PrimaryMap(comptime K: type, comptime V: type) type {
    return struct {
        elems: std.ArrayList(V),

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return .{ .elems = std.ArrayList(V).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.elems.deinit();
        }

        pub fn isValid(self: *const Self, k: K) bool {
            return k.index < self.elems.items.len;
        }

        pub fn get(self: *const Self, k: K) ?*const V {
            if (k.index >= self.elems.items.len) return null;
            return &self.elems.items[k.index];
        }

        pub fn getMut(self: *Self, k: K) ?*V {
            if (k.index >= self.elems.items.len) return null;
            return &self.elems.items[k.index];
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.elems.items.len == 0;
        }

        pub fn len(self: *const Self) usize {
            return self.elems.items.len;
        }

        pub fn clear(self: *Self) void {
            self.elems.clearRetainingCapacity();
        }

        pub fn nextKey(self: *const Self) K {
            return K.new(self.elems.items.len);
        }

        pub fn push(self: *Self, v: V) !K {
            const k = self.nextKey();
            try self.elems.append(v);
            return k;
        }

        pub fn last(self: *const Self) ?struct { K, *const V } {
            if (self.elems.items.len == 0) return null;
            const idx = self.elems.items.len - 1;
            return .{ K.new(idx), &self.elems.items[idx] };
        }

        pub fn lastMut(self: *Self) ?struct { K, *V } {
            if (self.elems.items.len == 0) return null;
            const idx = self.elems.items.len - 1;
            return .{ K.new(idx), &self.elems.items[idx] };
        }

        pub fn reserve(self: *Self, additional: usize) !void {
            try self.elems.ensureTotalCapacity(self.elems.items.len + additional);
        }
    };
}

/// Secondary map K -> V for sparse entity-indexed data.
///
/// Grows automatically when accessed. Uses Option<V> internally.
pub fn SecondaryMap(comptime K: type, comptime V: type) type {
    return struct {
        elems: std.ArrayList(?V),

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return .{ .elems = std.ArrayList(?V).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.elems.deinit();
        }

        pub fn clear(self: *Self) void {
            self.elems.clearRetainingCapacity();
        }

        pub fn get(self: *const Self, k: K) ?*const V {
            if (k.index >= self.elems.items.len) return null;
            if (self.elems.items[k.index]) |*v| return v;
            return null;
        }

        pub fn getMut(self: *Self, k: K) ?*V {
            if (k.index >= self.elems.items.len) return null;
            if (self.elems.items[k.index]) |*v| return v;
            return null;
        }

        pub fn getOrDefault(self: *Self, k: K) !*V {
            try self.resize(k.index + 1);
            if (self.elems.items[k.index] == null) {
                self.elems.items[k.index] = if (@sizeOf(V) == 0) {} else std.mem.zeroes(V);
            }
            return &self.elems.items[k.index].?;
        }

        pub fn set(self: *Self, k: K, v: V) !void {
            try self.resize(k.index + 1);
            self.elems.items[k.index] = v;
        }

        pub fn resize(self: *Self, new_len: usize) !void {
            if (new_len <= self.elems.items.len) return;
            try self.elems.resize(new_len);
            @memset(self.elems.items[self.elems.items.len..new_len], null);
        }
    };
}

const TestEntity = @import("entity.zig").EntityRef(u32, "test");

test "PrimaryMap basic" {
    var map = PrimaryMap(TestEntity, i32).init(testing.allocator);
    defer map.deinit();

    try testing.expect(map.isEmpty());
    try testing.expectEqual(0, map.len());

    const k1 = try map.push(42);
    try testing.expectEqual(TestEntity.new(0), k1);
    try testing.expectEqual(1, map.len());
    try testing.expect(map.isValid(k1));

    const k2 = try map.push(100);
    try testing.expectEqual(TestEntity.new(1), k2);
    try testing.expectEqual(2, map.len());

    try testing.expectEqual(42, map.get(k1).?.*);
    try testing.expectEqual(100, map.get(k2).?.*);
}

test "PrimaryMap nextKey" {
    var map = PrimaryMap(TestEntity, i32).init(testing.allocator);
    defer map.deinit();

    const next = map.nextKey();
    try testing.expectEqual(TestEntity.new(0), next);

    _ = try map.push(1);
    try testing.expectEqual(TestEntity.new(1), map.nextKey());
}

test "PrimaryMap last" {
    var map = PrimaryMap(TestEntity, i32).init(testing.allocator);
    defer map.deinit();

    try testing.expect(map.last() == null);

    _ = try map.push(10);
    _ = try map.push(20);

    const last = map.last().?;
    try testing.expectEqual(TestEntity.new(1), last[0]);
    try testing.expectEqual(20, last[1].*);
}

test "SecondaryMap basic" {
    var map = SecondaryMap(TestEntity, i32).init(testing.allocator);
    defer map.deinit();

    const k1 = TestEntity.new(0);
    const k5 = TestEntity.new(5);

    try map.set(k1, 42);
    try testing.expectEqual(42, map.get(k1).?.*);

    try map.set(k5, 100);
    try testing.expectEqual(100, map.get(k5).?.*);
    try testing.expectEqual(42, map.get(k1).?.*);

    const k2 = TestEntity.new(2);
    try testing.expect(map.get(k2) == null);
}

test "SecondaryMap getOrDefault" {
    var map = SecondaryMap(TestEntity, i32).init(testing.allocator);
    defer map.deinit();

    const k3 = TestEntity.new(3);
    const v = try map.getOrDefault(k3);
    try testing.expectEqual(0, v.*);

    v.* = 55;
    try testing.expectEqual(55, map.get(k3).?.*);
}
