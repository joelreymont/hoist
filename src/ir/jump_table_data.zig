const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const block_call = @import("block_call.zig");

const BlockCall = block_call.BlockCall;

/// Jump table data - switch table with default block.
///
/// First entry is always the default block.
pub const JumpTableData = struct {
    table: std.ArrayList(BlockCall),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .table = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.table.deinit(self.allocator);
    }

    pub fn new(allocator: Allocator, default: BlockCall, entries: []const BlockCall) !Self {
        var self = init(allocator);
        try self.table.append(self.allocator, default);
        try self.table.appendSlice(self.allocator, entries);
        return self;
    }

    pub fn defaultBlock(self: *const Self) ?BlockCall {
        if (self.table.items.len == 0) return null;
        return self.table.items[0];
    }

    pub fn defaultBlockMut(self: *Self) ?*BlockCall {
        if (self.table.items.len == 0) return null;
        return &self.table.items[0];
    }

    pub fn allBranches(self: *const Self) []const BlockCall {
        return self.table.items;
    }

    pub fn allBranchesMut(self: *Self) []BlockCall {
        return self.table.items;
    }

    pub fn asSlice(self: *const Self) []const BlockCall {
        if (self.table.items.len <= 1) return &.{};
        return self.table.items[1..];
    }

    pub fn asSliceMut(self: *Self) []BlockCall {
        if (self.table.items.len <= 1) return &.{};
        return self.table.items[1..];
    }

    pub fn len(self: *const Self) usize {
        if (self.table.items.len == 0) return 0;
        return self.table.items.len - 1;
    }

    pub fn format(self: Self, writer: anytype) !void {
        try writer.print("JumpTable{{ default={?}, entries={} }}", .{
            self.defaultBlock(),
            self.len(),
        });
    }
};

test "JumpTableData init" {
    var jt = JumpTableData.init(testing.allocator);
    defer jt.deinit();

    try testing.expect(jt.defaultBlock() == null);
    try testing.expectEqual(@as(usize, 0), jt.len());
}

test "JumpTableData new" {
    const ValueListPool = @import("value_list.zig").ValueListPool;
    const Block = @import("entities.zig").Block;

    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit(testing.allocator);

    const default = try BlockCall.new(Block.new(0), &.{}, &pool);
    const entries = [_]BlockCall{
        try BlockCall.new(Block.new(1), &.{}, &pool),
        try BlockCall.new(Block.new(2), &.{}, &pool),
        try BlockCall.new(Block.new(3), &.{}, &pool),
    };

    var jt = try JumpTableData.new(testing.allocator, default, &entries);
    defer jt.deinit();

    try testing.expectEqual(default, jt.defaultBlock().?);
    try testing.expectEqual(@as(usize, 3), jt.len());

    const slice = jt.asSlice();
    try testing.expectEqual(@as(usize, 3), slice.len);
}

test "JumpTableData allBranches" {
    const ValueListPool = @import("value_list.zig").ValueListPool;
    const Block = @import("entities.zig").Block;

    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit(testing.allocator);

    const default = try BlockCall.new(Block.new(0), &.{}, &pool);
    const entries = [_]BlockCall{
        try BlockCall.new(Block.new(1), &.{}, &pool),
        try BlockCall.new(Block.new(2), &.{}, &pool),
    };

    var jt = try JumpTableData.new(testing.allocator, default, &entries);
    defer jt.deinit();

    const all = jt.allBranches();
    try testing.expectEqual(@as(usize, 3), all.len);
    try testing.expectEqual(default, all[0]);
}

test "JumpTableData mutability" {
    const ValueListPool = @import("value_list.zig").ValueListPool;
    const Block = @import("entities.zig").Block;

    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit(testing.allocator);

    const default = try BlockCall.new(Block.new(0), &.{}, &pool);
    var jt = try JumpTableData.new(testing.allocator, default, &.{});
    defer jt.deinit();

    const def_mut = jt.defaultBlockMut().?;
    def_mut.* = try BlockCall.new(Block.new(99), &.{}, &pool);

    const new_default = try BlockCall.new(Block.new(99), &.{}, &pool);
    try testing.expectEqual(new_default, jt.defaultBlock().?);
}
