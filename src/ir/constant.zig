const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const entities = @import("entities.zig");

const Constant = entities.Constant;

/// Constant data stored in little-endian byte order.
pub const ConstantData = struct {
    bytes: std.ArrayList(u8),

    pub fn init(_allocator: Allocator) ConstantData {
        return .{ .bytes = std.ArrayList(u8){} };
    }

    pub fn fromSlice(allocator: Allocator, data: []const u8) !ConstantData {
        var c = init(allocator);
        try c.bytes.appendSlice(data);
        return c;
    }

    pub fn deinit(self: *ConstantData) void {
        self.bytes.deinit();
    }

    pub fn len(self: *const ConstantData) usize {
        return self.bytes.items.len;
    }

    pub fn isEmpty(self: *const ConstantData) bool {
        return self.bytes.items.len == 0;
    }

    pub fn asSlice(self: *const ConstantData) []const u8 {
        return self.bytes.items;
    }

    pub fn append(self: *ConstantData, data: []const u8) !void {
        try self.bytes.appendSlice(data);
    }

    pub fn expandTo(self: *ConstantData, expected_size: usize) !void {
        if (self.len() > expected_size) {
            return error.AlreadyExpanded;
        }
        try self.bytes.resize(expected_size);
        @memset(self.bytes.items[self.bytes.items.len..], 0);
    }

    pub fn clone(self: *const ConstantData, allocator: Allocator) !ConstantData {
        return try fromSlice(allocator, self.bytes.items);
    }

    pub fn eql(self: *const ConstantData, other: *const ConstantData) bool {
        return std.mem.eql(u8, self.bytes.items, other.bytes.items);
    }

    pub fn hash(self: *const ConstantData) u64 {
        return std.hash.Wyhash.hash(0, self.bytes.items);
    }

    pub fn format(self: ConstantData, writer: anytype) !void {
        if (self.isEmpty()) return;
        try writer.writeAll("0x");
        var i = self.bytes.items.len;
        while (i > 0) {
            i -= 1;
            try writer.print("{x:0>2}", .{self.bytes.items[i]});
        }
    }
};

/// Constant pool - maintains mapping between Constant handles and data.
/// Deduplicates constant data.
pub const ConstantPool = struct {
    allocator: Allocator,
    handles_to_values: std.AutoHashMap(Constant, ConstantData),
    values_to_handles: std.HashMap(u64, Constant, HashContext, std.hash_map.default_max_load_percentage),

    const HashContext = struct {
        pub fn hash(_: HashContext, key: u64) u64 {
            return key;
        }
        pub fn eql(_: HashContext, a: u64, b: u64) bool {
            return a == b;
        }
    };

    pub fn init(allocator: Allocator) ConstantPool {
        return .{
            .allocator = allocator,
            .handles_to_values = std.AutoHashMap(Constant, ConstantData).init(allocator),
            .values_to_handles = std.HashMap(u64, Constant, HashContext, std.hash_map.default_max_load_percentage).init(allocator),
        };
    }

    pub fn deinit(self: *ConstantPool) void {
        var it = self.handles_to_values.valueIterator();
        while (it.next()) |data| {
            var mut_data = data;
            mut_data.deinit();
        }
        self.handles_to_values.deinit();
        self.values_to_handles.deinit();
    }

    pub fn clear(self: *ConstantPool) void {
        var it = self.handles_to_values.valueIterator();
        while (it.next()) |data| {
            var mut_data = data;
            mut_data.deinit();
        }
        self.handles_to_values.clearRetainingCapacity();
        self.values_to_handles.clearRetainingCapacity();
    }

    pub fn insert(self: *ConstantPool, data: ConstantData) !Constant {
        const h = data.hash();
        if (self.values_to_handles.get(h)) |handle| {
            return handle;
        }

        const handle = Constant.new(self.handles_to_values.count());
        try self.set(handle, data);
        return handle;
    }

    pub fn get(self: *const ConstantPool, handle: Constant) ?*const ConstantData {
        return self.handles_to_values.getPtr(handle);
    }

    pub fn set(self: *ConstantPool, handle: Constant, data: ConstantData) !void {
        const h = data.hash();
        const cloned = try data.clone(self.allocator);
        try self.handles_to_values.put(handle, cloned);
        try self.values_to_handles.put(h, handle);
    }

    pub fn len(self: *const ConstantPool) usize {
        return self.handles_to_values.count();
    }

    pub fn byteSize(self: *const ConstantPool) usize {
        var total: usize = 0;
        var it = self.handles_to_values.valueIterator();
        while (it.next()) |data| {
            total += data.len();
        }
        return total;
    }
};

test "ConstantData basic" {
    var data = try ConstantData.fromSlice(testing.allocator, &[_]u8{ 1, 2, 3 });
    defer data.deinit();

    try testing.expectEqual(3, data.len());
    try testing.expect(!data.isEmpty());
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3 }, data.asSlice());
}

test "ConstantData append" {
    var data = ConstantData.init(testing.allocator);
    defer data.deinit();

    try data.append(&[_]u8{ 1, 2 });
    try data.append(&[_]u8{ 3, 4 });

    try testing.expectEqual(4, data.len());
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4 }, data.asSlice());
}

test "ConstantData eql" {
    var data1 = try ConstantData.fromSlice(testing.allocator, &[_]u8{ 1, 2, 3 });
    defer data1.deinit();
    var data2 = try ConstantData.fromSlice(testing.allocator, &[_]u8{ 1, 2, 3 });
    defer data2.deinit();
    var data3 = try ConstantData.fromSlice(testing.allocator, &[_]u8{ 1, 2, 4 });
    defer data3.deinit();

    try testing.expect(data1.eql(&data2));
    try testing.expect(!data1.eql(&data3));
}

test "ConstantPool empty" {
    var pool = ConstantPool.init(testing.allocator);
    defer pool.deinit();

    try testing.expectEqual(0, pool.len());
}

test "ConstantPool insert" {
    var pool = ConstantPool.init(testing.allocator);
    defer pool.deinit();

    const data1 = try ConstantData.fromSlice(testing.allocator, &[_]u8{ 1, 2, 3 });
    const data2 = try ConstantData.fromSlice(testing.allocator, &[_]u8{ 4, 5, 6 });

    _ = try pool.insert(data1);
    _ = try pool.insert(data2);

    try testing.expectEqual(2, pool.len());
}

test "ConstantPool deduplication" {
    var pool = ConstantPool.init(testing.allocator);
    defer pool.deinit();

    const data1 = try ConstantData.fromSlice(testing.allocator, &[_]u8{ 1, 2, 3 });
    const data2 = try ConstantData.fromSlice(testing.allocator, &[_]u8{ 4, 5, 6 });
    const data3 = try ConstantData.fromSlice(testing.allocator, &[_]u8{ 1, 2, 3 });

    const handle1 = try pool.insert(data1);
    _ = try pool.insert(data2);
    const handle3 = try pool.insert(data3);

    try testing.expectEqual(handle1, handle3);
    try testing.expectEqual(2, pool.len());
}

test "ConstantPool get" {
    var pool = ConstantPool.init(testing.allocator);
    defer pool.deinit();

    const data = try ConstantData.fromSlice(testing.allocator, &[_]u8{ 1, 2, 3 });
    const handle = try pool.insert(data);

    const retrieved = pool.get(handle).?;
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3 }, retrieved.asSlice());
}

test "ConstantData format" {
    var data = try ConstantData.fromSlice(testing.allocator, &[_]u8{ 3, 2, 1, 0, 0 });
    defer data.deinit();

    var buf: [32]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try data.format(fbs.writer());

    try testing.expectEqualStrings("0x0000010203", fbs.getWritten());
}
