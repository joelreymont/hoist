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

    pub fn deinit(self: *DominatorTree, allocator: std.mem.Allocator) void {
        self.idom.deinit(self.allocator);

        var iter = self.children.valueIterator();
        while (iter.next()) |list| {
            list.deinit();
        }
        self.children.deinit();
    }

    /// Compute dominator tree using Semi-NCA algorithm.
    /// Based on "A Simple, Fast Dominance Algorithm" by Cooper, Harvey, Kennedy.
    pub fn compute(
        self: *DominatorTree,
        allocator: Allocator,
        entry: Block,
        cfg: *const CFG,
    ) !void {
        // Clear existing dominator tree
        self.idom.deinit(allocator);
        var child_iter = self.children.valueIterator();
        while (child_iter.next()) |list| {
            list.deinit();
        }
        self.children.clearRetainingCapacity();
        self.idom = PrimaryMap(Block, ?Block).init();

        // Entry block has no immediate dominator
        try self.idom.set(allocator, entry, null);

        // Compute reverse postorder (approximated by iterating over blocks)
        var blocks = std.ArrayList(Block){};
        defer blocks.deinit();

        // Collect all blocks reachable from entry via DFS
        try self.collectReachableBlocks(allocator, &blocks, entry, cfg);

        if (blocks.items.len == 0) return;

        // Initialize all blocks' idoms to null
        for (blocks.items) |block| {
            if (!std.meta.eql(block, entry)) {
                try self.idom.set(allocator, block, null);
            }
        }

        // Iterate until convergence (simple fixed-point iteration)
        var changed = true;
        while (changed) {
            changed = false;

            for (blocks.items) |block| {
                if (std.meta.eql(block, entry)) continue;

                // Find first processed predecessor
                const preds = cfg.predecessors(block);
                if (preds.len == 0) continue;

                var new_idom: ?Block = null;
                for (preds) |pred| {
                    if (self.idom.get(pred)) |_| {
                        new_idom = pred;
                        break;
                    }
                }

                // Intersect with all other processed predecessors
                for (preds) |pred| {
                    if (new_idom) |idom| {
                        if (!std.meta.eql(pred, idom) and self.idom.get(pred) != null) {
                            new_idom = self.intersect(pred, idom);
                        }
                    }
                }

                // Update if changed
                const old_idom = self.idom.get(block) orelse null;
                if (new_idom) |idom| {
                    if (old_idom == null or !std.meta.eql(idom, old_idom.?)) {
                        try self.idom.set(allocator, block, idom);
                        changed = true;
                    }
                }
            }
        }

        // Build dominator tree children
        for (blocks.items) |block| {
            if (self.idom.get(block)) |maybe_idom| {
                if (maybe_idom) |idom_block| {
                    const entry_result = try self.children.getOrPut(idom_block);
                    if (!entry_result.found_existing) {
                        entry_result.value_ptr.* = std.ArrayList(Block){};
                    }
                    try entry_result.value_ptr.append(block);
                }
            }
        }
    }

    fn collectReachableBlocks(
        self: *DominatorTree,
        allocator: Allocator,
        blocks: *std.ArrayList(Block),
        entry: Block,
        cfg: *const CFG,
    ) !void {
        _ = self;
        var visited = std.AutoHashMap(Block, void).init(allocator);
        defer visited.deinit();

        var worklist = std.ArrayList(Block){};
        defer worklist.deinit();

        try worklist.append(entry);
        try visited.put(entry, {});

        while (worklist.items.len > 0) {
            const block = worklist.pop();
            try blocks.append(block);

            for (cfg.successors(block)) |succ| {
                if (!visited.contains(succ)) {
                    try visited.put(succ, {});
                    try worklist.append(succ);
                }
            }
        }
    }

    fn intersect(self: *const DominatorTree, b1: Block, b2: Block) Block {
        var finger1 = b1;
        var finger2 = b2;

        while (!std.meta.eql(finger1, finger2)) {
            while (self.blockDepth(finger1) > self.blockDepth(finger2)) {
                finger1 = self.idom.get(finger1) orelse break;
            }
            while (self.blockDepth(finger2) > self.blockDepth(finger1)) {
                finger2 = self.idom.get(finger2) orelse break;
            }

            if (std.meta.eql(finger1, finger2)) break;

            const idom1 = self.idom.get(finger1) orelse break;
            const idom2 = self.idom.get(finger2) orelse break;

            finger1 = idom1 orelse break;
            finger2 = idom2 orelse break;
        }

        return finger1;
    }

    fn blockDepth(self: *const DominatorTree, block: Block) u32 {
        var depth: u32 = 0;
        var current = block;
        while (self.idom.get(current)) |maybe_idom| {
            const idom_block = maybe_idom orelse return depth;
            depth += 1;
            current = idom_block;
        }
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

    /// Compute dominance frontier for a block.
    /// The dominance frontier of X is the set of all nodes Y such that:
    /// - X dominates a predecessor of Y, but
    /// - X does not strictly dominate Y
    pub fn dominanceFrontier(
        self: *const DominatorTree,
        allocator: Allocator,
        block: Block,
        cfg: *const CFG,
    ) !std.ArrayList(Block) {
        var frontier = std.ArrayList(Block){};

        // For each successor of blocks dominated by 'block'
        var dominated = try self.getDominatedBlocks(allocator, block);
        defer dominated.deinit();

        for (dominated.items) |dom_block| {
            const succs = cfg.successors(dom_block);
            for (succs) |succ| {
                // If block dominates dom_block but doesn't strictly dominate succ,
                // then succ is in the dominance frontier
                if (!self.strictlyDominates(block, succ)) {
                    // Add to frontier if not already present
                    var found = false;
                    for (frontier.items) |f| {
                        if (std.meta.eql(f, succ)) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        try frontier.append(succ);
                    }
                }
            }
        }

        return frontier;
    }

    /// Get all blocks dominated by a given block.
    fn getDominatedBlocks(
        self: *const DominatorTree,
        _allocator: Allocator,
        block: Block,
    ) !std.ArrayList(Block) {
        _ = _allocator;
        var dominated = std.ArrayList(Block){};

        // Add the block itself
        try dominated.append(block);

        // Recursively add all dominated blocks via children
        try self.collectDominatedRecursive(&dominated, block);

        return dominated;
    }

    fn collectDominatedRecursive(
        self: *const DominatorTree,
        dominated: *std.ArrayList(Block),
        block: Block,
    ) !void {
        const children_list = self.getChildren(block);
        for (children_list) |child| {
            try dominated.append(child);
            try self.collectDominatedRecursive(dominated, child);
        }
    }

    fn strictlyDominates(self: *const DominatorTree, a: Block, b: Block) bool {
        if (std.meta.eql(a, b)) return false;
        return self.dominates(a, b);
    }

    /// Verify dominator tree properties.
    /// Returns error if invariants are violated.
    pub fn verify(self: *const DominatorTree, allocator: Allocator, entry: Block, cfg: *const CFG) !void {
        // 1. Entry block should have no idom
        if (self.idom.get(entry)) |maybe_entry_idom| {
            if (maybe_entry_idom != null) {
                return error.EntryBlockHasIdom;
            }
        }

        // 2. Every reachable block (except entry) should have an idom
        var reachable = std.AutoHashMap(Block, void).init(allocator);
        defer reachable.deinit();

        // Compute reachable blocks from entry via CFG
        var worklist = std.ArrayList(Block){};
        defer worklist.deinit();

        try worklist.append(entry);
        try reachable.put(entry, {});

        while (worklist.items.len > 0) {
            const block = worklist.pop();
            const succs = cfg.successors(block);
            for (succs) |succ| {
                if (!reachable.contains(succ)) {
                    try reachable.put(succ, {});
                    try worklist.append(succ);
                }
            }
        }

        // Check all reachable blocks have idom (except entry)
        var iter = reachable.keyIterator();
        while (iter.next()) |block| {
            if (std.meta.eql(block.*, entry)) continue;

            if (self.idom.get(block.*)) |maybe_idom| {
                if (maybe_idom == null) {
                    return error.ReachableBlockWithoutIdom;
                }
            } else {
                return error.ReachableBlockWithoutIdom;
            }
        }

        // 3. Verify dominator property: idom(b) must dominate all predecessors of b
        iter = reachable.keyIterator();
        while (iter.next()) |block| {
            if (std.meta.eql(block.*, entry)) continue;

            const idom_block = self.idom.get(block.*) orelse continue;
            const idom = idom_block orelse continue;

            const preds = cfg.predecessors(block.*);
            for (preds) |pred| {
                if (!self.dominates(idom, pred)) {
                    return error.IdomDoesNotDominatePredecessor;
                }
            }
        }

        // 4. Verify no cycles in dominator tree
        iter = reachable.keyIterator();
        while (iter.next()) |block| {
            var visited = std.AutoHashMap(Block, void).init(allocator);
            defer visited.deinit();

            var current = block.*;
            while (self.idom.get(current)) |maybe_idom| {
                const idom = maybe_idom orelse break;

                if (visited.contains(idom)) {
                    return error.DominatorTreeCycle;
                }
                try visited.put(idom, {});
                current = idom;
            }
        }
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

/// Post-dominator tree for control flow analysis.
/// Post-dominance: Block X post-dominates Y if all paths from Y to exit go through X.
pub const PostDominatorTree = struct {
    /// Immediate post-dominator for each block.
    ipdom: PrimaryMap(Block, ?Block),

    /// Post-dominator tree children.
    children: std.AutoHashMap(Block, std.ArrayList(Block)),

    /// Allocator.
    allocator: Allocator,

    pub fn init(allocator: Allocator) PostDominatorTree {
        return .{
            .ipdom = PrimaryMap(Block, ?Block).init(),
            .children = std.AutoHashMap(Block, std.ArrayList(Block)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PostDominatorTree) void {
        self.ipdom.deinit(self.allocator);

        var iter = self.children.valueIterator();
        while (iter.next()) |list| {
            list.deinit();
        }
        self.children.deinit();
    }

    /// Compute post-dominator tree using reverse CFG.
    /// Same algorithm as dominator tree but on reversed edges.
    pub fn compute(
        self: *PostDominatorTree,
        allocator: Allocator,
        exit: Block,
        cfg: *const CFG,
    ) !void {
        // Clear existing tree
        self.ipdom.deinit(allocator);
        var child_iter = self.children.valueIterator();
        while (child_iter.next()) |list| {
            list.deinit();
        }
        self.children.clearRetainingCapacity();
        self.ipdom = PrimaryMap(Block, ?Block).init();

        // Exit block has no immediate post-dominator
        try self.ipdom.set(allocator, exit, null);

        // Build reverse postorder from exit (using predecessors as successors)
        var rpo = std.ArrayList(Block){};
        defer rpo.deinit();

        var visited = std.AutoHashMap(Block, void).init(allocator);
        defer visited.deinit();

        try collectReachableReverse(cfg, exit, &visited, &rpo);
        std.mem.reverse(Block, rpo.items);

        // Fixed-point iteration
        var changed = true;
        while (changed) {
            changed = false;

            for (rpo.items) |block| {
                if (std.meta.eql(block, exit)) continue;

                // Compute ipdom as intersection of successors' ipdoms
                const succs = cfg.successors(block);
                if (succs.len == 0) continue;

                var new_ipdom: ?Block = null;
                for (succs) |succ| {
                    const succ_ipdom = self.ipdom.get(succ) orelse continue;
                    if (succ_ipdom) |s_ipdom| {
                        new_ipdom = if (new_ipdom) |n| intersect(self, n, s_ipdom, allocator) else s_ipdom;
                    }
                }

                const old_ipdom = self.ipdom.get(block) orelse null;
                if (!std.meta.eql(old_ipdom, new_ipdom)) {
                    try self.ipdom.set(allocator, block, new_ipdom);
                    changed = true;
                }
            }
        }

        // Build children map
        for (rpo.items) |block| {
            if (self.ipdom.get(block)) |maybe_ipdom| {
                if (maybe_ipdom) |ipdom| {
                    const entry = try self.children.getOrPut(ipdom);
                    if (!entry.found_existing) {
                        entry.value_ptr.* = std.ArrayList(Block){};
                    }
                    try entry.value_ptr.append(block);
                }
            }
        }
    }

    /// Check if block `a` post-dominates block `b`.
    pub fn postDominates(self: *const PostDominatorTree, a: Block, b: Block) bool {
        if (std.meta.eql(a, b)) return true;

        var current = b;
        while (self.ipdom.get(current)) |maybe_ipdom| {
            const ipdom = maybe_ipdom orelse break;
            if (std.meta.eql(ipdom, a)) return true;
            current = ipdom;
        } else {
            return false;
        }
        return false;
    }

    /// Get immediate post-dominator of a block.
    pub fn ipostDominator(self: *const PostDominatorTree, block: Block) ?Block {
        return self.ipdom.get(block) orelse null;
    }
};

fn collectReachableReverse(
    cfg: *const CFG,
    block: Block,
    visited: *std.AutoHashMap(Block, void),
    postorder: *std.ArrayList(Block),
) !void {
    if (visited.contains(block)) return;
    try visited.put(block, {});

    // Visit predecessors (reverse direction)
    const preds = cfg.predecessors(block);
    for (preds) |pred| {
        try collectReachableReverse(cfg, pred, visited, postorder);
    }

    try postorder.append(block);
}

fn intersect(
    tree: *const PostDominatorTree,
    b1: Block,
    b2: Block,
    allocator: Allocator,
) Block {
    _ = allocator;
    var finger1 = b1;
    var finger2 = b2;

    while (!std.meta.eql(finger1, finger2)) {
        while (blockDepthPdom(tree, finger1) > blockDepthPdom(tree, finger2)) {
            const ipdom = tree.ipdom.get(finger1) orelse break;
            finger1 = ipdom orelse break;
        }
        while (blockDepthPdom(tree, finger2) > blockDepthPdom(tree, finger1)) {
            const ipdom = tree.ipdom.get(finger2) orelse break;
            finger2 = ipdom orelse break;
        }

        if (std.meta.eql(finger1, finger2)) break;

        const ipdom1 = tree.ipdom.get(finger1) orelse break;
        const ipdom2 = tree.ipdom.get(finger2) orelse break;

        finger1 = ipdom1 orelse break;
        finger2 = ipdom2 orelse break;
    }

    return finger1;
}

fn blockDepthPdom(tree: *const PostDominatorTree, block: Block) u32 {
    var depth: u32 = 0;
    var current = block;
    while (tree.ipdom.get(current)) |maybe_ipdom| {
        const ipdom = maybe_ipdom orelse return depth;
        depth += 1;
        current = ipdom;
    }
    return depth;
}

test "PostDominatorTree basic" {
    var tree = PostDominatorTree.init(testing.allocator);
    defer tree.deinit();

    const exit = Block.new(0);
    try tree.ipdom.set(testing.allocator, exit, null);

    try testing.expect(tree.ipostDominator(exit) == null);
}

// Helper to build linear CFG for testing
fn buildLinearCFG(cfg: *CFG, blocks: []const Block) !void {
    for (0..blocks.len - 1) |i| {
        try cfg.addEdge(blocks[i], blocks[i + 1]);
    }
}

test "DominatorTree: linear CFG dominators" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = [_]Block{
        Block.new(0),
        Block.new(1),
        Block.new(2),
    };

    try buildLinearCFG(&cfg, &blocks);
    try tree.compute(testing.allocator, blocks[0], &cfg);

    try testing.expect(tree.idominator(blocks[0]) == null);

    const b1_idom = tree.idominator(blocks[1]).?;
    try testing.expect(std.meta.eql(b1_idom, blocks[0]));

    const b2_idom = tree.idominator(blocks[2]).?;
    try testing.expect(std.meta.eql(b2_idom, blocks[1]));
}

test "DominatorTree: diamond CFG dominators" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b0, b2);
    try cfg.addEdge(b1, b3);
    try cfg.addEdge(b2, b3);

    try tree.compute(testing.allocator, b0, &cfg);

    try testing.expect(tree.idominator(b0) == null);

    const b1_idom = tree.idominator(b1).?;
    try testing.expect(std.meta.eql(b1_idom, b0));

    const b2_idom = tree.idominator(b2).?;
    try testing.expect(std.meta.eql(b2_idom, b0));

    const b3_idom = tree.idominator(b3).?;
    try testing.expect(std.meta.eql(b3_idom, b0));
}

test "DominatorTree: loop CFG dominators" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b1, b2);
    try cfg.addEdge(b2, b1);

    try tree.compute(testing.allocator, b0, &cfg);

    try testing.expect(tree.idominator(b0) == null);

    const b1_idom = tree.idominator(b1).?;
    try testing.expect(std.meta.eql(b1_idom, b0));

    const b2_idom = tree.idominator(b2).?;
    try testing.expect(std.meta.eql(b2_idom, b1));
}

test "DominatorTree: dominates - transitive" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = [_]Block{
        Block.new(0),
        Block.new(1),
        Block.new(2),
        Block.new(3),
    };

    try buildLinearCFG(&cfg, &blocks);
    try tree.compute(testing.allocator, blocks[0], &cfg);

    try testing.expect(tree.dominates(blocks[0], blocks[1]));
    try testing.expect(tree.dominates(blocks[0], blocks[2]));
    try testing.expect(tree.dominates(blocks[0], blocks[3]));
    try testing.expect(tree.dominates(blocks[1], blocks[2]));
    try testing.expect(tree.dominates(blocks[1], blocks[3]));
    try testing.expect(tree.dominates(blocks[2], blocks[3]));
    try testing.expect(!tree.dominates(blocks[1], blocks[0]));
    try testing.expect(!tree.dominates(blocks[2], blocks[0]));
}

test "DominatorTree: getChildren - linear" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = [_]Block{
        Block.new(0),
        Block.new(1),
        Block.new(2),
    };

    try buildLinearCFG(&cfg, &blocks);
    try tree.compute(testing.allocator, blocks[0], &cfg);

    const b0_children = tree.getChildren(blocks[0]);
    try testing.expectEqual(@as(usize, 1), b0_children.len);
    try testing.expect(std.meta.eql(b0_children[0], blocks[1]));

    const b1_children = tree.getChildren(blocks[1]);
    try testing.expectEqual(@as(usize, 1), b1_children.len);
    try testing.expect(std.meta.eql(b1_children[0], blocks[2]));

    const b2_children = tree.getChildren(blocks[2]);
    try testing.expectEqual(@as(usize, 0), b2_children.len);
}

test "DominatorTree: getChildren - diamond" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b0, b2);
    try cfg.addEdge(b1, b3);
    try cfg.addEdge(b2, b3);

    try tree.compute(testing.allocator, b0, &cfg);

    const b0_children = tree.getChildren(b0);
    try testing.expectEqual(@as(usize, 3), b0_children.len);

    try testing.expectEqual(@as(usize, 0), tree.getChildren(b1).len);
    try testing.expectEqual(@as(usize, 0), tree.getChildren(b2).len);
    try testing.expectEqual(@as(usize, 0), tree.getChildren(b3).len);
}

test "DominatorTree: dominance frontier - diamond" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b0, b2);
    try cfg.addEdge(b1, b3);
    try cfg.addEdge(b2, b3);

    try tree.compute(testing.allocator, b0, &cfg);

    var df_b1 = try tree.dominanceFrontier(testing.allocator, b1, &cfg);
    defer df_b1.deinit();
    try testing.expectEqual(@as(usize, 1), df_b1.items.len);
    try testing.expect(std.meta.eql(df_b1.items[0], b3));

    var df_b2 = try tree.dominanceFrontier(testing.allocator, b2, &cfg);
    defer df_b2.deinit();
    try testing.expectEqual(@as(usize, 1), df_b2.items.len);
    try testing.expect(std.meta.eql(df_b2.items[0], b3));

    var df_b0 = try tree.dominanceFrontier(testing.allocator, b0, &cfg);
    defer df_b0.deinit();
    try testing.expectEqual(@as(usize, 0), df_b0.items.len);
}

test "DominatorTree: dominance frontier - loop" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b1, b2);
    try cfg.addEdge(b2, b1);

    try tree.compute(testing.allocator, b0, &cfg);

    var df_b2 = try tree.dominanceFrontier(testing.allocator, b2, &cfg);
    defer df_b2.deinit();
    try testing.expectEqual(@as(usize, 1), df_b2.items.len);
    try testing.expect(std.meta.eql(df_b2.items[0], b1));

    var df_b1 = try tree.dominanceFrontier(testing.allocator, b1, &cfg);
    defer df_b1.deinit();
    try testing.expectEqual(@as(usize, 1), df_b1.items.len);
    try testing.expect(std.meta.eql(df_b1.items[0], b1));
}

test "DominatorTree: verify - valid tree" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = [_]Block{
        Block.new(0),
        Block.new(1),
        Block.new(2),
    };

    try buildLinearCFG(&cfg, &blocks);
    try tree.compute(testing.allocator, blocks[0], &cfg);

    try tree.verify(testing.allocator, blocks[0], &cfg);
}

test "DominatorTree: verify - entry has idom fails" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);

    try tree.idom.set(testing.allocator, b0, b1);

    const result = tree.verify(testing.allocator, b0, &cfg);
    try testing.expectError(error.EntryBlockHasIdom, result);
}

test "DominatorTree: isReachable" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    try cfg.addEdge(b0, b1);

    try tree.compute(testing.allocator, b0, &cfg);

    try testing.expect(tree.isReachable(b0));
    try testing.expect(tree.isReachable(b1));
    try testing.expect(!tree.isReachable(b2));
}

test "PostDominatorTree: linear CFG" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = PostDominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = [_]Block{
        Block.new(0),
        Block.new(1),
        Block.new(2),
    };

    try buildLinearCFG(&cfg, &blocks);
    try tree.compute(testing.allocator, blocks[2], &cfg);

    try testing.expect(tree.ipostDominator(blocks[2]) == null);

    const b1_ipdom = tree.ipostDominator(blocks[1]).?;
    try testing.expect(std.meta.eql(b1_ipdom, blocks[2]));

    const b0_ipdom = tree.ipostDominator(blocks[0]).?;
    try testing.expect(std.meta.eql(b0_ipdom, blocks[1]));
}

test "PostDominatorTree: diamond" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = PostDominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b0, b2);
    try cfg.addEdge(b1, b3);
    try cfg.addEdge(b2, b3);

    try tree.compute(testing.allocator, b3, &cfg);

    try testing.expect(tree.ipostDominator(b3) == null);

    const b1_ipdom = tree.ipostDominator(b1).?;
    try testing.expect(std.meta.eql(b1_ipdom, b3));

    const b2_ipdom = tree.ipostDominator(b2).?;
    try testing.expect(std.meta.eql(b2_ipdom, b3));

    const b0_ipdom = tree.ipostDominator(b0).?;
    try testing.expect(std.meta.eql(b0_ipdom, b3));
}

test "PostDominatorTree: postDominates" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = PostDominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = [_]Block{
        Block.new(0),
        Block.new(1),
        Block.new(2),
    };

    try buildLinearCFG(&cfg, &blocks);
    try tree.compute(testing.allocator, blocks[2], &cfg);

    try testing.expect(tree.postDominates(blocks[0], blocks[0]));
    try testing.expect(tree.postDominates(blocks[1], blocks[1]));
    try testing.expect(tree.postDominates(blocks[2], blocks[2]));
    try testing.expect(tree.postDominates(blocks[2], blocks[0]));
    try testing.expect(tree.postDominates(blocks[2], blocks[1]));
    try testing.expect(!tree.postDominates(blocks[0], blocks[2]));
}

test "DominatorTree: single block CFG" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);

    try tree.compute(testing.allocator, b0, &cfg);

    try testing.expect(tree.idominator(b0) == null);
    try testing.expect(tree.dominates(b0, b0));
    try testing.expect(tree.isReachable(b0));
    try testing.expectEqual(@as(usize, 0), tree.getChildren(b0).len);
}

test "DominatorTree: complex CFG" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);
    const b4 = Block.new(4);
    const b5 = Block.new(5);
    const b6 = Block.new(6);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b0, b2);
    try cfg.addEdge(b1, b3);
    try cfg.addEdge(b1, b4);
    try cfg.addEdge(b2, b3);
    try cfg.addEdge(b2, b5);
    try cfg.addEdge(b3, b4);
    try cfg.addEdge(b3, b5);
    try cfg.addEdge(b4, b6);
    try cfg.addEdge(b5, b6);

    try tree.compute(testing.allocator, b0, &cfg);

    try testing.expect(tree.dominates(b0, b1));
    try testing.expect(tree.dominates(b0, b2));
    try testing.expect(tree.dominates(b0, b3));
    try testing.expect(tree.dominates(b0, b4));
    try testing.expect(tree.dominates(b0, b5));
    try testing.expect(tree.dominates(b0, b6));

    try testing.expect(std.meta.eql(tree.idominator(b3).?, b0));

    try tree.verify(testing.allocator, b0, &cfg);
}
