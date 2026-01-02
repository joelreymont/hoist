const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const entity = root.entity;
const entities = @import("entities.zig");

const Value = entities.Value;

/// Small list of entity references allocated from a pool.
///
/// Provides similar functionality to Vec<T> but with:
/// - Memory allocated from ListPool instead of global heap
/// - 4-byte footprint vs 24 bytes for Vec
/// - No Drop implementation, pool manages memory
///
/// Layout in pool:
/// 1. Length field (1 element)
/// 2. List elements
/// 3. Excess capacity
///
/// Total size is always power of two, excess capacity minimized.
/// Index 0 represents empty list.
pub const ValueList = packed struct {
    index: u32 = 0,

    pub fn default() ValueList {
        return .{};
    }

    /// Check if list is empty (doesn't require pool access).
    pub fn isEmpty(self: ValueList) bool {
        return self.index == 0;
    }
};

/// Memory pool for storing lists of Values.
///
/// Implements LIFO allocation with power-of-two size classes.
/// After building data structures with many lists, clear pool to reclaim all memory.
pub const ValueListPool = struct {
    /// Main array containing all lists
    data: std.ArrayList(Value),
    /// Heads of free lists, one per size class
    free_lists: std.ArrayList(usize),
    allocator: Allocator,

    const SizeClass = u8;

    /// Get size of a size class (includes length field).
    fn sclassSize(sclass: SizeClass) usize {
        return @as(usize, 4) << sclass;
    }

    /// Get size class for a given list length.
    fn sclassForLength(length: usize) SizeClass {
        const adjusted: u32 = @intCast(@max(length, 3));
        return @intCast(30 - @clz(adjusted | 3));
    }

    /// Check if length is minimum in its size class.
    fn isSclassMinLength(length: usize) bool {
        return length > 3 and std.math.isPowerOfTwo(length);
    }

    pub fn init(allocator: Allocator) ValueListPool {
        return .{
            .data = .{},
            .free_lists = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ValueListPool) void {
        self.data.deinit(self.allocator);
        self.free_lists.deinit(self.allocator);
    }

    /// Clear pool, invalidating all existing lists.
    pub fn clear(self: *ValueListPool) void {
        self.data.clearRetainingCapacity();
        self.free_lists.clearRetainingCapacity();
    }

    /// Get length of a list.
    pub fn len(self: *const ValueListPool, list: ValueList) usize {
        if (list.index == 0) return 0;
        const idx: usize = list.index;
        return self.data.items[idx -% 1].index;
    }

    /// Allocate storage block with given size class.
    fn alloc(self: *ValueListPool, sclass: SizeClass) !usize {
        const sc: usize = sclass;
        if (sc < self.free_lists.items.len) {
            const head = self.free_lists.items[sc];
            if (head > 0) {
                // Reuse from free list
                self.free_lists.items[sc] = self.data.items[head].index;
                return head - 1;
            }
        }
        // Allocate new block
        const offset = self.data.items.len;
        const size = sclassSize(sclass);
        const reserved = Value.invalid;
        try self.data.ensureTotalCapacity(self.allocator, offset + size);
        var i: usize = 0;
        while (i < size) : (i += 1) {
            self.data.appendAssumeCapacity(self.allocator, reserved);
        }
        return offset;
    }

    /// Free a storage block.
    fn free(self: *ValueListPool, block: usize, sclass: SizeClass) !void {
        const sc: usize = sclass;
        if (sc >= self.free_lists.items.len) {
            try self.free_lists.resize(sc + 1);
            var i = self.free_lists.items.len;
            while (i <= sc) : (i += 1) {
                self.free_lists.items[i] = 0;
            }
        }
        self.data.items[block] = Value.new(0);
        self.data.items[block + 1] = Value.new(self.free_lists.items[sc]);
        self.free_lists.items[sc] = block + 1;
    }

    /// Get immutable slice of list elements.
    pub fn asSlice(self: *const ValueListPool, list: ValueList) []const Value {
        if (list.index == 0) return &.{};
        const idx: usize = list.index;
        const length = self.len(list);
        return self.data.items[idx .. idx + length];
    }

    /// Get mutable slice of list elements.
    pub fn asMutSlice(self: *ValueListPool, list: ValueList) []Value {
        if (list.index == 0) return &.{};
        const idx: usize = list.index;
        const length = self.len(list);
        return self.data.items[idx .. idx + length];
    }

    /// Get element at index.
    pub fn get(self: *const ValueListPool, list: ValueList, idx: usize) ?Value {
        const slice = self.asSlice(list);
        if (idx >= slice.len) return null;
        return slice[idx];
    }

    /// Get mutable element at index.
    pub fn getMut(self: *ValueListPool, list: ValueList, idx: usize) ?*Value {
        const slice = self.asMutSlice(list);
        if (idx >= slice.len) return null;
        return &slice[idx];
    }

    /// Get first element.
    pub fn first(self: *const ValueListPool, list: ValueList) ?Value {
        return self.get(list, 0);
    }

    /// Push element to list.
    pub fn push(self: *ValueListPool, list: *ValueList, value: Value) !void {
        const old_len = self.len(list.*);
        const new_len = old_len + 1;
        const new_sclass = sclassForLength(new_len);

        if (list.index == 0) {
            // Empty list, allocate new
            const block = try self.alloc(new_sclass);
            self.data.items[block] = Value.new(new_len);
            self.data.items[block + 1] = value;
            list.index = @intCast(block + 1);
        } else if (isSclassMinLength(new_len)) {
            // Need to grow to next size class
            const old_sclass = sclassForLength(old_len);
            const old_block = list.index - 1;
            const new_block = try self.alloc(new_sclass);

            // Copy old data
            const old_data = self.data.items[old_block + 1 .. old_block + 1 + old_len];
            @memcpy(self.data.items[new_block + 1 .. new_block + 1 + old_len], old_data);
            self.data.items[new_block] = Value.new(new_len);
            self.data.items[new_block + 1 + old_len] = value;

            try self.free(old_block, old_sclass);
            list.index = @intCast(new_block + 1);
        } else {
            // Fits in current size class
            const block = list.index - 1;
            self.data.items[block] = Value.new(new_len);
            self.data.items[list.index + old_len] = value;
        }
    }

    /// Extend list with multiple values.
    pub fn extend(self: *ValueListPool, list: *ValueList, values: []const Value) !void {
        for (values) |v| {
            try self.push(list, v);
        }
    }

    /// Remove element at index.
    pub fn remove(self: *ValueListPool, list: *ValueList, idx: usize) !void {
        const old_len = self.len(list.*);
        if (idx >= old_len) return;

        const new_len = old_len - 1;
        if (new_len == 0) {
            const old_sclass = sclassForLength(old_len);
            try self.free(list.index - 1, old_sclass);
            list.index = 0;
            return;
        }

        const slice = self.asMutSlice(list.*);
        std.mem.copyForwards(Value, slice[idx..], slice[idx + 1 ..]);

        const new_sclass = sclassForLength(new_len);
        const old_sclass = sclassForLength(old_len);

        if (new_sclass != old_sclass) {
            // Shrink to smaller size class
            const old_block = list.index - 1;
            const new_block = try self.alloc(new_sclass);

            const old_data = self.data.items[old_block + 1 .. old_block + 1 + new_len];
            @memcpy(self.data.items[new_block + 1 .. new_block + 1 + new_len], old_data);
            self.data.items[new_block] = Value.new(new_len);

            try self.free(old_block, old_sclass);
            list.index = @intCast(new_block + 1);
        } else {
            self.data.items[list.index - 1] = Value.new(new_len);
        }
    }

    /// Truncate list to new length.
    pub fn truncate(self: *ValueListPool, list: *ValueList, new_len: usize) !void {
        const old_len = self.len(list.*);
        if (new_len >= old_len) return;

        if (new_len == 0) {
            const old_sclass = sclassForLength(old_len);
            try self.free(list.index - 1, old_sclass);
            list.index = 0;
            return;
        }

        const new_sclass = sclassForLength(new_len);
        const old_sclass = sclassForLength(old_len);

        if (new_sclass != old_sclass) {
            const old_block = list.index - 1;
            const new_block = try self.alloc(new_sclass);

            const old_data = self.data.items[old_block + 1 .. old_block + 1 + new_len];
            @memcpy(self.data.items[new_block + 1 .. new_block + 1 + new_len], old_data);
            self.data.items[new_block] = Value.new(new_len);

            try self.free(old_block, old_sclass);
            list.index = @intCast(new_block + 1);
        } else {
            self.data.items[list.index - 1] = Value.new(new_len);
        }
    }

    /// Deep clone list in same pool.
    pub fn deepClone(self: *ValueListPool, list: ValueList) !ValueList {
        if (list.index == 0) return ValueList.default();

        const old_len = self.len(list);
        const sclass = sclassForLength(old_len);
        const new_block = try self.alloc(sclass);

        const old_data = self.asSlice(list);
        @memcpy(self.data.items[new_block + 1 .. new_block + 1 + old_len], old_data);
        self.data.items[new_block] = Value.new(old_len);

        return .{ .index = @intCast(new_block + 1) };
    }
};

test "ValueListPool basic operations" {
    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit();

    var list = ValueList.default();
    try testing.expect(list.isEmpty());
    try testing.expectEqual(0, pool.len(list));

    try pool.push(&list, Value.new(1));
    try testing.expectEqual(1, pool.len(list));
    try testing.expectEqual(Value.new(1), pool.first(list).?);

    try pool.push(&list, Value.new(2));
    try testing.expectEqual(2, pool.len(list));
    try testing.expectEqual(Value.new(2), pool.get(list, 1).?);
}

test "ValueListPool extend" {
    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit();

    var list = ValueList.default();
    const values = [_]Value{ Value.new(10), Value.new(20), Value.new(30) };
    try pool.extend(&list, &values);

    try testing.expectEqual(3, pool.len(list));
    try testing.expectEqual(Value.new(10), pool.get(list, 0).?);
    try testing.expectEqual(Value.new(20), pool.get(list, 1).?);
    try testing.expectEqual(Value.new(30), pool.get(list, 2).?);
}

test "ValueListPool remove" {
    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit();

    var list = ValueList.default();
    const values = [_]Value{ Value.new(1), Value.new(2), Value.new(3) };
    try pool.extend(&list, &values);

    try pool.remove(&list, 1);
    try testing.expectEqual(2, pool.len(list));
    try testing.expectEqual(Value.new(1), pool.get(list, 0).?);
    try testing.expectEqual(Value.new(3), pool.get(list, 1).?);
}

test "ValueListPool truncate" {
    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit();

    var list = ValueList.default();
    const values = [_]Value{ Value.new(1), Value.new(2), Value.new(3), Value.new(4) };
    try pool.extend(&list, &values);

    try pool.truncate(&list, 2);
    try testing.expectEqual(2, pool.len(list));
    try testing.expectEqual(Value.new(1), pool.get(list, 0).?);
    try testing.expectEqual(Value.new(2), pool.get(list, 1).?);
}

test "ValueListPool deep clone" {
    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit();

    var list1 = ValueList.default();
    const values = [_]Value{ Value.new(1), Value.new(2) };
    try pool.extend(&list1, &values);

    const list2 = try pool.deepClone(list1);
    try testing.expectEqual(pool.len(list1), pool.len(list2));
    try testing.expectEqual(pool.get(list1, 0).?, pool.get(list2, 0).?);
    try testing.expectEqual(pool.get(list1, 1).?, pool.get(list2, 1).?);
}
