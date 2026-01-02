const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const Block = root.entities.Block;

/// Block ordering for code emission.
/// Determines the order in which basic blocks are emitted in the final code.
pub const BlockOrder = struct {
    /// Ordered list of blocks.
    blocks: std.ArrayList(Block),
    allocator: Allocator,

    pub fn init(allocator: Allocator) BlockOrder {
        return .{
            .blocks = std.ArrayList(Block).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BlockOrder) void {
        self.blocks.deinit();
    }

    /// Get the ordered blocks.
    pub fn order(self: *const BlockOrder) []const Block {
        return self.blocks.items;
    }

    /// Add a block to the order.
    pub fn append(self: *BlockOrder, block: Block) !void {
        try self.blocks.append(block);
    }

    /// Clear the order.
    pub fn clear(self: *BlockOrder) void {
        self.blocks.clearRetainingCapacity();
    }
};

/// Compute block order using reverse postorder traversal.
/// This places frequently executed blocks earlier for better code locality.
pub fn computeOrder(
    allocator: Allocator,
    blocks: []const Block,
    cfg: anytype,
    entry: Block,
) !BlockOrder {
    var order = BlockOrder.init(allocator);
    errdefer order.deinit();

    // Use reverse postorder for good code locality
    var visited = std.AutoHashMap(Block, void).init(allocator);
    defer visited.deinit();

    var postorder = std.ArrayList(Block).init(allocator);
    defer postorder.deinit();

    try dfsPostorder(cfg, entry, &visited, &postorder);

    // Reverse to get reverse postorder
    std.mem.reverse(Block, postorder.items);

    // Add blocks in reverse postorder
    for (postorder.items) |block| {
        try order.append(block);
    }

    // Add unreachable blocks at the end
    for (blocks) |block| {
        if (!visited.contains(block)) {
            try order.append(block);
        }
    }

    return order;
}

fn dfsPostorder(
    cfg: anytype,
    block: Block,
    visited: *std.AutoHashMap(Block, void),
    postorder: *std.ArrayList(Block),
) !void {
    if (visited.contains(block)) return;
    try visited.put(block, {});

    // Visit successors
    var succ_iter = cfg.succIter(block);
    while (succ_iter.next()) |succ| {
        try dfsPostorder(cfg, succ, visited, postorder);
    }

    try postorder.append(block);
}

test "BlockOrder basic" {
    var order = BlockOrder.init(testing.allocator);
    defer order.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);

    try order.append(b0);
    try order.append(b1);

    const blocks = order.order();
    try testing.expectEqual(@as(usize, 2), blocks.len);
    try testing.expectEqual(b0, blocks[0]);
    try testing.expectEqual(b1, blocks[1]);
}

test "BlockOrder clear" {
    var order = BlockOrder.init(testing.allocator);
    defer order.deinit();

    try order.append(Block.new(0));
    try testing.expectEqual(@as(usize, 1), order.blocks.items.len);

    order.clear();
    try testing.expectEqual(@as(usize, 0), order.blocks.items.len);
}
