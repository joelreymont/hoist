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

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{ .table = std.ArrayList(BlockCall).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.table.deinit();
    }

    pub fn new(allocator: Allocator, default: BlockCall, entries: []const BlockCall) !Self {
        var self = init(allocator);
        try self.table.append(default);
        try self.table.appendSlice(entries);
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
    const default = BlockCall.new(0);
    const entries = [_]BlockCall{ BlockCall.new(1), BlockCall.new(2), BlockCall.new(3) };

    var jt = try JumpTableData.new(testing.allocator, default, &entries);
    defer jt.deinit();

    try testing.expectEqual(default, jt.defaultBlock().?);
    try testing.expectEqual(@as(usize, 3), jt.len());

    const slice = jt.asSlice();
    try testing.expectEqual(@as(usize, 3), slice.len);
    try testing.expectEqual(BlockCall.new(1), slice[0]);
    try testing.expectEqual(BlockCall.new(2), slice[1]);
    try testing.expectEqual(BlockCall.new(3), slice[2]);
}

test "JumpTableData allBranches" {
    const default = BlockCall.new(0);
    const entries = [_]BlockCall{ BlockCall.new(1), BlockCall.new(2) };

    var jt = try JumpTableData.new(testing.allocator, default, &entries);
    defer jt.deinit();

    const all = jt.allBranches();
    try testing.expectEqual(@as(usize, 3), all.len);
    try testing.expectEqual(default, all[0]);
    try testing.expectEqual(BlockCall.new(1), all[1]);
    try testing.expectEqual(BlockCall.new(2), all[2]);
}

test "JumpTableData mutability" {
    const default = BlockCall.new(0);
    var jt = try JumpTableData.new(testing.allocator, default, &.{});
    defer jt.deinit();

    const def_mut = jt.defaultBlockMut().?;
    def_mut.* = BlockCall.new(99);

    try testing.expectEqual(BlockCall.new(99), jt.defaultBlock().?);
}
