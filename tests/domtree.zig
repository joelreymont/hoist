const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const DominatorTree = hoist.ir.domtree.DominatorTree;
const ControlFlowGraph = hoist.ir.cfg.ControlFlowGraph;
const Block = hoist.ir.Block;
const Inst = hoist.ir.Inst;

/// Build a diamond CFG:
///   entry -> left
///   entry -> right
///   left -> exit
///   right -> exit
fn buildDiamondCFG(cfg: *ControlFlowGraph) !struct {
    entry: Block,
    left: Block,
    right: Block,
    exit: Block,
} {
    const entry = Block.new(0);
    const left = Block.new(1);
    const right = Block.new(2);
    const exit = Block.new(3);

    try cfg.addEdge(entry, Inst.new(0), left);
    try cfg.addEdge(entry, Inst.new(1), right);
    try cfg.addEdge(left, Inst.new(2), exit);
    try cfg.addEdge(right, Inst.new(3), exit);

    return .{
        .entry = entry,
        .left = left,
        .right = right,
        .exit = exit,
    };
}

test "domtree: diamond CFG structure" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit(testing.allocator);

    const blocks = try buildDiamondCFG(&cfg);

    // Verify CFG structure
    try testing.expectEqual(@as(usize, 2), cfg.successorCount(blocks.entry));
    try testing.expectEqual(@as(usize, 1), cfg.successorCount(blocks.left));
    try testing.expectEqual(@as(usize, 1), cfg.successorCount(blocks.right));
    try testing.expectEqual(@as(usize, 0), cfg.successorCount(blocks.exit));

    try testing.expectEqual(@as(usize, 0), cfg.predecessorCount(blocks.entry));
    try testing.expectEqual(@as(usize, 1), cfg.predecessorCount(blocks.left));
    try testing.expectEqual(@as(usize, 1), cfg.predecessorCount(blocks.right));
    try testing.expectEqual(@as(usize, 2), cfg.predecessorCount(blocks.exit));
}

test "domtree: diamond CFG entry dominates all" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit(testing.allocator);

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = try buildDiamondCFG(&cfg);

    try tree.compute(testing.allocator, blocks.entry, &cfg);

    // Entry should dominate all blocks (including itself)
    try testing.expect(tree.dominates(blocks.entry, blocks.entry));
    try testing.expect(tree.dominates(blocks.entry, blocks.left));
    try testing.expect(tree.dominates(blocks.entry, blocks.right));
    try testing.expect(tree.dominates(blocks.entry, blocks.exit));
}

test "domtree: diamond CFG left and right dominance" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit(testing.allocator);

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = try buildDiamondCFG(&cfg);

    try tree.compute(testing.allocator, blocks.entry, &cfg);

    // Left should dominate itself, but not exit or right
    try testing.expect(tree.dominates(blocks.left, blocks.left));
    try testing.expect(!tree.dominates(blocks.left, blocks.exit));
    try testing.expect(!tree.dominates(blocks.left, blocks.right));

    // Right should dominate itself, but not exit or left
    try testing.expect(tree.dominates(blocks.right, blocks.right));
    try testing.expect(!tree.dominates(blocks.right, blocks.exit));
    try testing.expect(!tree.dominates(blocks.right, blocks.left));

    // Left and right do not dominate each other
    try testing.expect(!tree.dominates(blocks.left, blocks.right));
    try testing.expect(!tree.dominates(blocks.right, blocks.left));
}

test "domtree: diamond CFG immediate dominators" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit(testing.allocator);

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = try buildDiamondCFG(&cfg);

    try tree.compute(testing.allocator, blocks.entry, &cfg);

    // Entry has no idom
    try testing.expect(tree.idominator(blocks.entry) == null);

    // Left and right are immediately dominated by entry
    const left_idom = tree.idominator(blocks.left).?;
    try testing.expect(std.meta.eql(left_idom, blocks.entry));

    const right_idom = tree.idominator(blocks.right).?;
    try testing.expect(std.meta.eql(right_idom, blocks.entry));

    // Exit is immediately dominated by entry (not left or right)
    const exit_idom = tree.idominator(blocks.exit).?;
    try testing.expect(std.meta.eql(exit_idom, blocks.entry));
}

test "domtree: diamond CFG dominator tree children" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit(testing.allocator);

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = try buildDiamondCFG(&cfg);

    try tree.compute(testing.allocator, blocks.entry, &cfg);

    // Entry should have all three other blocks as children
    const entry_children = tree.getChildren(blocks.entry);
    try testing.expectEqual(@as(usize, 3), entry_children.len);

    // Check that all children are present (order might vary)
    var has_left = false;
    var has_right = false;
    var has_exit = false;
    for (entry_children) |child| {
        if (std.meta.eql(child, blocks.left)) has_left = true;
        if (std.meta.eql(child, blocks.right)) has_right = true;
        if (std.meta.eql(child, blocks.exit)) has_exit = true;
    }
    try testing.expect(has_left and has_right and has_exit);

    // Left, right, and exit should have no children
    try testing.expectEqual(@as(usize, 0), tree.getChildren(blocks.left).len);
    try testing.expectEqual(@as(usize, 0), tree.getChildren(blocks.right).len);
    try testing.expectEqual(@as(usize, 0), tree.getChildren(blocks.exit).len);
}

test "domtree: diamond CFG dominance frontier" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit(testing.allocator);

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = try buildDiamondCFG(&cfg);

    try tree.compute(testing.allocator, blocks.entry, &cfg);

    // Dominance frontier of left should be {exit}
    var df_left = try tree.dominanceFrontier(testing.allocator, blocks.left, &cfg);
    defer df_left.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), df_left.items.len);
    try testing.expect(std.meta.eql(df_left.items[0], blocks.exit));

    // Dominance frontier of right should be {exit}
    var df_right = try tree.dominanceFrontier(testing.allocator, blocks.right, &cfg);
    defer df_right.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), df_right.items.len);
    try testing.expect(std.meta.eql(df_right.items[0], blocks.exit));

    // Dominance frontier of entry should be empty
    var df_entry = try tree.dominanceFrontier(testing.allocator, blocks.entry, &cfg);
    defer df_entry.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), df_entry.items.len);
}

test "domtree: diamond CFG reachability" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit(testing.allocator);

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = try buildDiamondCFG(&cfg);

    try tree.compute(testing.allocator, blocks.entry, &cfg);

    // All blocks should be reachable from entry
    try testing.expect(tree.isReachable(blocks.entry));
    try testing.expect(tree.isReachable(blocks.left));
    try testing.expect(tree.isReachable(blocks.right));
    try testing.expect(tree.isReachable(blocks.exit));
}

test "domtree: diamond CFG verify" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit(testing.allocator);

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = try buildDiamondCFG(&cfg);

    try tree.compute(testing.allocator, blocks.entry, &cfg);

    // Verify the dominator tree is valid
    try tree.verify(testing.allocator, blocks.entry, &cfg);
}

test "domtree: diamond CFG exit dominated by all" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit(testing.allocator);

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const blocks = try buildDiamondCFG(&cfg);

    try tree.compute(testing.allocator, blocks.entry, &cfg);

    // Exit should be dominated by entry only
    // Left and right do not dominate exit
    try testing.expect(!tree.dominates(blocks.left, blocks.exit));
    try testing.expect(!tree.dominates(blocks.right, blocks.exit));
    try testing.expect(std.meta.eql(tree.idominator(blocks.exit).?, blocks.entry));
}
