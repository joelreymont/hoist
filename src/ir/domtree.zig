const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("root");
const Block = root.entities.Block;
const PrimaryMap = root.maps.PrimaryMap;

/// Dominator tree for control flow analysis.
/// Computes dominance relationships between basic blocks.
pub const DominatorTree = struct {
    /// Immediate dominator for each block.
    /// idom[b] is the block that immediately dominates b.
    idom: PrimaryMap(Block, ?Block),

    /// Dominator tree children.
    /// children[b] contains all blocks immediately dominated by b.
    children: std.AutoHashMap(Block, std.ArrayList(Block)),

    /// Allocator.
    allocator: Allocator,

    pub fn init(allocator: Allocator) DominatorTree {
        return .{
            .idom = PrimaryMap(Block, ?Block).init(),
            .children = std.AutoHashMap(Block, std.ArrayList(Block)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DominatorTree) void {
        self.idom.deinit(self.allocator);

        var iter = self.children.valueIterator();
        while (iter.next()) |list| {
            list.deinit();
        }
        self.children.deinit();
    }

    /// Compute dominator tree using Lengauer-Tarjan algorithm.
    /// This is a simplified version - full implementation needs reverse postorder.
    pub fn compute(
        self: *DominatorTree,
        allocator: Allocator,
        entry: Block,
        cfg: *const CFG,
    ) !void {
        _ = cfg;

        // For bootstrap: entry block dominates itself, has no idom
        try self.idom.set(allocator, entry, null);

        // TODO: Implement full Lengauer-Tarjan algorithm
        // 1. Compute reverse postorder traversal
        // 2. Initialize semi-dominators
        // 3. Compute immediate dominators
        // 4. Build dominator tree
    }

    /// Check if block `a` dominates block `b`.
    pub fn dominates(self: *const DominatorTree, a: Block, b: Block) bool {
        if (std.meta.eql(a, b)) return true;

        var current = b;
        while (self.idom.get(current)) |maybe_idom| {
            const idom_block = maybe_idom orelse break;
            if (std.meta.eql(idom_block, a)) return true;
            current = idom_block;
        } else {
            return false;
        }
        return false;
    }

    /// Get immediate dominator of a block.
    pub fn idominator(self: *const DominatorTree, block: Block) ?Block {
        return self.idom.get(block) orelse null;
    }

    /// Get dominator tree children of a block.
    pub fn getChildren(self: *const DominatorTree, block: Block) []const Block {
        if (self.children.get(block)) |list| {
            return list.items;
        }
        return &.{};
    }

    /// Check if block is reachable from entry.
    pub fn isReachable(self: *const DominatorTree, block: Block) bool {
        return self.idom.get(block) != null;
    }
};

/// Control flow graph representation (stub for domtree computation).
pub const CFG = struct {
    /// Predecessors for each block.
    preds: std.AutoHashMap(Block, std.ArrayList(Block)),

    /// Successors for each block.
    succs: std.AutoHashMap(Block, std.ArrayList(Block)),

    /// Allocator.
    allocator: Allocator,

    pub fn init(allocator: Allocator) CFG {
        return .{
            .preds = std.AutoHashMap(Block, std.ArrayList(Block)).init(allocator),
            .succs = std.AutoHashMap(Block, std.ArrayList(Block)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CFG) void {
        var pred_iter = self.preds.valueIterator();
        while (pred_iter.next()) |list| {
            list.deinit();
        }
        self.preds.deinit();

        var succ_iter = self.succs.valueIterator();
        while (succ_iter.next()) |list| {
            list.deinit();
        }
        self.succs.deinit();
    }

    /// Add an edge from `from` to `to`.
    pub fn addEdge(self: *CFG, from: Block, to: Block) !void {
        // Add to successors of `from`
        const succ_entry = try self.succs.getOrPut(from);
        if (!succ_entry.found_existing) {
            succ_entry.value_ptr.* = std.ArrayList(Block).init(self.allocator);
        }
        try succ_entry.value_ptr.append(to);

        // Add to predecessors of `to`
        const pred_entry = try self.preds.getOrPut(to);
        if (!pred_entry.found_existing) {
            pred_entry.value_ptr.* = std.ArrayList(Block).init(self.allocator);
        }
        try pred_entry.value_ptr.append(from);
    }

    /// Get predecessors of a block.
    pub fn predecessors(self: *const CFG, block: Block) []const Block {
        if (self.preds.get(block)) |list| {
            return list.items;
        }
        return &.{};
    }

    /// Get successors of a block.
    pub fn successors(self: *const CFG, block: Block) []const Block {
        if (self.succs.get(block)) |list| {
            return list.items;
        }
        return &.{};
    }
};

test "DominatorTree basic" {
    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);

    // Set b0 as entry (no idom)
    try tree.idom.set(testing.allocator, b0, null);

    // Set b0 as idom of b1
    try tree.idom.set(testing.allocator, b1, b0);

    // b0 dominates b1
    try testing.expect(tree.dominates(b0, b1));

    // b1 doesn't dominate b0
    try testing.expect(!tree.dominates(b1, b0));

    // Every block dominates itself
    try testing.expect(tree.dominates(b0, b0));
    try testing.expect(tree.dominates(b1, b1));
}

test "CFG basic" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    // Add edges: b0 -> b1, b0 -> b2, b1 -> b2
    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b0, b2);
    try cfg.addEdge(b1, b2);

    // Check successors of b0
    const b0_succs = cfg.successors(b0);
    try testing.expectEqual(@as(usize, 2), b0_succs.len);

    // Check predecessors of b2
    const b2_preds = cfg.predecessors(b2);
    try testing.expectEqual(@as(usize, 2), b2_preds.len);

    // b1 has one predecessor
    const b1_preds = cfg.predecessors(b1);
    try testing.expectEqual(@as(usize, 1), b1_preds.len);
}

test "DominatorTree idominator" {
    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);

    try tree.idom.set(testing.allocator, b0, null);
    try tree.idom.set(testing.allocator, b1, b0);

    // b0 has no idom (entry)
    try testing.expect(tree.idominator(b0) == null);

    // b1's idom is b0
    const b1_idom = tree.idominator(b1).?;
    try testing.expect(std.meta.eql(b1_idom, b0));
}
