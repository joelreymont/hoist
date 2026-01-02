const std = @import("std");
const testing = std.testing;

const root = @import("root");
const domtree_mod = root.domtree;
const DominatorTree = domtree_mod.DominatorTree;
const PostDominatorTree = domtree_mod.PostDominatorTree;
const CFG = domtree_mod.CFG;
const Block = root.entities.Block;

// Helper to build a simple CFG for testing
fn buildLinearCFG(cfg: *CFG, blocks: []const Block) !void {
    for (0..blocks.len - 1) |i| {
        try cfg.addEdge(blocks[i], blocks[i + 1]);
    }
}

// Test: Basic dominator tree initialization

test "DominatorTree: initialization and cleanup" {
    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Tree should be empty initially
    const b0 = Block.new(0);
    try testing.expect(tree.idominator(b0) == null);
}

test "DominatorTree: entry block has no idom" {
    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const entry = Block.new(0);
    try tree.idom.set(testing.allocator, entry, null);

    try testing.expect(tree.idominator(entry) == null);
}

// Test: Immediate dominator computation

test "DominatorTree: linear CFG dominators" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Linear: B0 -> B1 -> B2
    const blocks = [_]Block{
        Block.new(0),
        Block.new(1),
        Block.new(2),
    };

    try buildLinearCFG(&cfg, &blocks);

    // Compute dominators
    try tree.compute(testing.allocator, blocks[0], &cfg);

    // B0 is entry (no idom)
    try testing.expect(tree.idominator(blocks[0]) == null);

    // B1's idom is B0
    const b1_idom = tree.idominator(blocks[1]).?;
    try testing.expect(std.meta.eql(b1_idom, blocks[0]));

    // B2's idom is B1
    const b2_idom = tree.idominator(blocks[2]).?;
    try testing.expect(std.meta.eql(b2_idom, blocks[1]));
}

test "DominatorTree: diamond CFG dominators" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Diamond pattern:
    //     B0
    //    /  \
    //   B1  B2
    //    \  /
    //     B3

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b0, b2);
    try cfg.addEdge(b1, b3);
    try cfg.addEdge(b2, b3);

    try tree.compute(testing.allocator, b0, &cfg);

    // B0 is entry
    try testing.expect(tree.idominator(b0) == null);

    // B1's idom is B0
    const b1_idom = tree.idominator(b1).?;
    try testing.expect(std.meta.eql(b1_idom, b0));

    // B2's idom is B0
    const b2_idom = tree.idominator(b2).?;
    try testing.expect(std.meta.eql(b2_idom, b0));

    // B3's idom is B0 (common dominator of B1 and B2)
    const b3_idom = tree.idominator(b3).?;
    try testing.expect(std.meta.eql(b3_idom, b0));
}

test "DominatorTree: loop CFG dominators" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Loop pattern:
    //   B0 -> B1 -> B2
    //         ^      |
    //         |______|

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b1, b2);
    try cfg.addEdge(b2, b1); // Back edge

    try tree.compute(testing.allocator, b0, &cfg);

    // B0 is entry
    try testing.expect(tree.idominator(b0) == null);

    // B1's idom is B0 (despite back edge from B2)
    const b1_idom = tree.idominator(b1).?;
    try testing.expect(std.meta.eql(b1_idom, b0));

    // B2's idom is B1
    const b2_idom = tree.idominator(b2).?;
    try testing.expect(std.meta.eql(b2_idom, b1));
}

test "DominatorTree: nested loops dominators" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Nested loops:
    //   B0 -> B1 -> B2 -> B3
    //         ^     |     |
    //         |_____|     |
    //         |___________|

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b1, b2);
    try cfg.addEdge(b2, b3);
    try cfg.addEdge(b3, b1); // Outer loop back edge
    try cfg.addEdge(b2, b1); // Inner loop back edge

    try tree.compute(testing.allocator, b0, &cfg);

    // Verify idoms
    try testing.expect(tree.idominator(b0) == null);
    try testing.expect(std.meta.eql(tree.idominator(b1).?, b0));
    try testing.expect(std.meta.eql(tree.idominator(b2).?, b1));
    try testing.expect(std.meta.eql(tree.idominator(b3).?, b2));
}

// Test: Dominance queries

test "DominatorTree: dominates - self dominance" {
    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);

    try tree.idom.set(testing.allocator, b0, null);
    try tree.idom.set(testing.allocator, b1, b0);

    // Every block dominates itself
    try testing.expect(tree.dominates(b0, b0));
    try testing.expect(tree.dominates(b1, b1));
}

test "DominatorTree: dominates - transitive" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Linear: B0 -> B1 -> B2 -> B3
    const blocks = [_]Block{
        Block.new(0),
        Block.new(1),
        Block.new(2),
        Block.new(3),
    };

    try buildLinearCFG(&cfg, &blocks);
    try tree.compute(testing.allocator, blocks[0], &cfg);

    // B0 dominates all blocks
    try testing.expect(tree.dominates(blocks[0], blocks[1]));
    try testing.expect(tree.dominates(blocks[0], blocks[2]));
    try testing.expect(tree.dominates(blocks[0], blocks[3]));

    // B1 dominates B2 and B3
    try testing.expect(tree.dominates(blocks[1], blocks[2]));
    try testing.expect(tree.dominates(blocks[1], blocks[3]));

    // B2 dominates B3
    try testing.expect(tree.dominates(blocks[2], blocks[3]));

    // Reverse dominance doesn't hold
    try testing.expect(!tree.dominates(blocks[1], blocks[0]));
    try testing.expect(!tree.dominates(blocks[2], blocks[0]));
    try testing.expect(!tree.dominates(blocks[3], blocks[0]));
}

test "DominatorTree: dominates - diamond pattern" {
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

    // B0 dominates all blocks
    try testing.expect(tree.dominates(b0, b1));
    try testing.expect(tree.dominates(b0, b2));
    try testing.expect(tree.dominates(b0, b3));

    // B1 doesn't dominate B2 or B3
    try testing.expect(!tree.dominates(b1, b2));
    try testing.expect(!tree.dominates(b1, b3));

    // B2 doesn't dominate B1 or B3
    try testing.expect(!tree.dominates(b2, b1));
    try testing.expect(!tree.dominates(b2, b3));
}

test "DominatorTree: dominates - unreachable blocks" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    // B0 -> B1, B2 is unreachable
    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    try cfg.addEdge(b0, b1);

    try tree.compute(testing.allocator, b0, &cfg);

    // B0 dominates B1
    try testing.expect(tree.dominates(b0, b1));

    // B2 is unreachable, not dominated by anything
    try testing.expect(!tree.isReachable(b2));
}

// Test: Dominator tree structure

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

    // B0 has one child: B1
    const b0_children = tree.getChildren(blocks[0]);
    try testing.expectEqual(@as(usize, 1), b0_children.len);
    try testing.expect(std.meta.eql(b0_children[0], blocks[1]));

    // B1 has one child: B2
    const b1_children = tree.getChildren(blocks[1]);
    try testing.expectEqual(@as(usize, 1), b1_children.len);
    try testing.expect(std.meta.eql(b1_children[0], blocks[2]));

    // B2 has no children
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

    // B0 has three children: B1, B2, B3
    const b0_children = tree.getChildren(b0);
    try testing.expectEqual(@as(usize, 3), b0_children.len);

    // B1, B2, B3 have no children
    try testing.expectEqual(@as(usize, 0), tree.getChildren(b1).len);
    try testing.expectEqual(@as(usize, 0), tree.getChildren(b2).len);
    try testing.expectEqual(@as(usize, 0), tree.getChildren(b3).len);
}

test "DominatorTree: getChildren - loop" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b1, b2);
    try cfg.addEdge(b2, b1); // Back edge

    try tree.compute(testing.allocator, b0, &cfg);

    // B0 has one child: B1
    const b0_children = tree.getChildren(b0);
    try testing.expectEqual(@as(usize, 1), b0_children.len);
    try testing.expect(std.meta.eql(b0_children[0], b1));

    // B1 has one child: B2 (despite back edge)
    const b1_children = tree.getChildren(b1);
    try testing.expectEqual(@as(usize, 1), b1_children.len);
    try testing.expect(std.meta.eql(b1_children[0], b2));
}

// Test: Dominance frontier computation

test "DominatorTree: dominance frontier - diamond" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Diamond:
    //     B0
    //    /  \
    //   B1  B2
    //    \  /
    //     B3

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b0, b2);
    try cfg.addEdge(b1, b3);
    try cfg.addEdge(b2, b3);

    try tree.compute(testing.allocator, b0, &cfg);

    // DF(B1) = {B3} (B1 dominates pred of B3 but not B3 itself)
    var df_b1 = try tree.dominanceFrontier(testing.allocator, b1, &cfg);
    defer df_b1.deinit();
    try testing.expectEqual(@as(usize, 1), df_b1.items.len);
    try testing.expect(std.meta.eql(df_b1.items[0], b3));

    // DF(B2) = {B3}
    var df_b2 = try tree.dominanceFrontier(testing.allocator, b2, &cfg);
    defer df_b2.deinit();
    try testing.expectEqual(@as(usize, 1), df_b2.items.len);
    try testing.expect(std.meta.eql(df_b2.items[0], b3));

    // DF(B0) = {} (B0 dominates all blocks)
    var df_b0 = try tree.dominanceFrontier(testing.allocator, b0, &cfg);
    defer df_b0.deinit();
    try testing.expectEqual(@as(usize, 0), df_b0.items.len);

    // DF(B3) = {} (leaf node)
    var df_b3 = try tree.dominanceFrontier(testing.allocator, b3, &cfg);
    defer df_b3.deinit();
    try testing.expectEqual(@as(usize, 0), df_b3.items.len);
}

test "DominatorTree: dominance frontier - loop" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Loop:
    //   B0 -> B1 -> B2
    //         ^      |
    //         |______|

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b1, b2);
    try cfg.addEdge(b2, b1); // Back edge

    try tree.compute(testing.allocator, b0, &cfg);

    // DF(B2) = {B1} (loop header in frontier)
    var df_b2 = try tree.dominanceFrontier(testing.allocator, b2, &cfg);
    defer df_b2.deinit();
    try testing.expectEqual(@as(usize, 1), df_b2.items.len);
    try testing.expect(std.meta.eql(df_b2.items[0], b1));

    // DF(B1) = {B1} (loop header dominates itself)
    var df_b1 = try tree.dominanceFrontier(testing.allocator, b1, &cfg);
    defer df_b1.deinit();
    try testing.expectEqual(@as(usize, 1), df_b1.items.len);
    try testing.expect(std.meta.eql(df_b1.items[0], b1));
}

test "DominatorTree: dominance frontier - multiple join points" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Complex CFG:
    //     B0
    //    /  \
    //   B1  B2
    //   |    |\
    //   B3   | \
    //    \  /   B4
    //     B5

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);
    const b4 = Block.new(4);
    const b5 = Block.new(5);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b0, b2);
    try cfg.addEdge(b1, b3);
    try cfg.addEdge(b3, b5);
    try cfg.addEdge(b2, b5);
    try cfg.addEdge(b2, b4);

    try tree.compute(testing.allocator, b0, &cfg);

    // DF(B1) should include B5
    var df_b1 = try tree.dominanceFrontier(testing.allocator, b1, &cfg);
    defer df_b1.deinit();

    var has_b5 = false;
    for (df_b1.items) |block| {
        if (std.meta.eql(block, b5)) has_b5 = true;
    }
    try testing.expect(has_b5);
}

// Test: Tree verification

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

    // Verification should pass
    try tree.verify(testing.allocator, blocks[0], &cfg);
}

test "DominatorTree: verify - entry has idom fails" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);

    // Manually set entry to have idom (invalid!)
    try tree.idom.set(testing.allocator, b0, b1);

    const result = tree.verify(testing.allocator, b0, &cfg);
    try testing.expectError(error.EntryBlockHasIdom, result);
}

test "DominatorTree: verify - diamond structure" {
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
    try tree.verify(testing.allocator, b0, &cfg);
}

// Test: Reachability

test "DominatorTree: isReachable - linear CFG" {
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

    // All blocks in linear CFG are reachable
    try testing.expect(tree.isReachable(blocks[0]));
    try testing.expect(tree.isReachable(blocks[1]));
    try testing.expect(tree.isReachable(blocks[2]));
}

test "DominatorTree: isReachable - unreachable block" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2); // Unreachable

    try cfg.addEdge(b0, b1);
    // B2 has no incoming edges

    try tree.compute(testing.allocator, b0, &cfg);

    try testing.expect(tree.isReachable(b0));
    try testing.expect(tree.isReachable(b1));
    try testing.expect(!tree.isReachable(b2));
}

// Test: Post-dominators

test "PostDominatorTree: initialization and cleanup" {
    var tree = PostDominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);
    try testing.expect(tree.ipostDominator(b0) == null);
}

test "PostDominatorTree: linear CFG post-dominators" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = PostDominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Linear: B0 -> B1 -> B2 (B2 is exit)
    const blocks = [_]Block{
        Block.new(0),
        Block.new(1),
        Block.new(2),
    };

    try buildLinearCFG(&cfg, &blocks);
    try tree.compute(testing.allocator, blocks[2], &cfg);

    // B2 is exit (no ipdom)
    try testing.expect(tree.ipostDominator(blocks[2]) == null);

    // B1's ipdom is B2
    const b1_ipdom = tree.ipostDominator(blocks[1]).?;
    try testing.expect(std.meta.eql(b1_ipdom, blocks[2]));

    // B0's ipdom is B1
    const b0_ipdom = tree.ipostDominator(blocks[0]).?;
    try testing.expect(std.meta.eql(b0_ipdom, blocks[1]));
}

test "PostDominatorTree: diamond post-dominators" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = PostDominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Diamond:
    //     B0
    //    /  \
    //   B1  B2
    //    \  /
    //     B3 (exit)

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b0, b2);
    try cfg.addEdge(b1, b3);
    try cfg.addEdge(b2, b3);

    try tree.compute(testing.allocator, b3, &cfg);

    // B3 is exit
    try testing.expect(tree.ipostDominator(b3) == null);

    // B1's ipdom is B3
    const b1_ipdom = tree.ipostDominator(b1).?;
    try testing.expect(std.meta.eql(b1_ipdom, b3));

    // B2's ipdom is B3
    const b2_ipdom = tree.ipostDominator(b2).?;
    try testing.expect(std.meta.eql(b2_ipdom, b3));

    // B0's ipdom is B3
    const b0_ipdom = tree.ipostDominator(b0).?;
    try testing.expect(std.meta.eql(b0_ipdom, b3));
}

test "PostDominatorTree: postDominates - linear" {
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

    // Every block post-dominates itself
    try testing.expect(tree.postDominates(blocks[0], blocks[0]));
    try testing.expect(tree.postDominates(blocks[1], blocks[1]));
    try testing.expect(tree.postDominates(blocks[2], blocks[2]));

    // Exit post-dominates all blocks
    try testing.expect(tree.postDominates(blocks[2], blocks[0]));
    try testing.expect(tree.postDominates(blocks[2], blocks[1]));

    // Reverse post-dominance doesn't hold
    try testing.expect(!tree.postDominates(blocks[0], blocks[2]));
    try testing.expect(!tree.postDominates(blocks[1], blocks[2]));
}

test "PostDominatorTree: postDominates - diamond" {
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

    // B3 post-dominates all blocks
    try testing.expect(tree.postDominates(b3, b0));
    try testing.expect(tree.postDominates(b3, b1));
    try testing.expect(tree.postDominates(b3, b2));

    // B1 doesn't post-dominate B0 (path B0->B2->B3 avoids B1)
    try testing.expect(!tree.postDominates(b1, b0));

    // B2 doesn't post-dominate B0 (path B0->B1->B3 avoids B2)
    try testing.expect(!tree.postDominates(b2, b0));
}

test "PostDominatorTree: loop with exit" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = PostDominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Loop with exit:
    //   B0 -> B1 -> B2 -> B3 (exit)
    //         ^      |
    //         |______|

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b1, b2);
    try cfg.addEdge(b2, b1); // Back edge
    try cfg.addEdge(b2, b3); // Loop exit

    try tree.compute(testing.allocator, b3, &cfg);

    // B3 post-dominates all blocks
    try testing.expect(tree.postDominates(b3, b0));
    try testing.expect(tree.postDominates(b3, b1));
    try testing.expect(tree.postDominates(b3, b2));
}

// Test: Edge cases

test "DominatorTree: single block CFG" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    const b0 = Block.new(0);

    try tree.compute(testing.allocator, b0, &cfg);

    // Single block has no idom
    try testing.expect(tree.idominator(b0) == null);

    // Block dominates itself
    try testing.expect(tree.dominates(b0, b0));

    // Block is reachable
    try testing.expect(tree.isReachable(b0));

    // No children
    try testing.expectEqual(@as(usize, 0), tree.getChildren(b0).len);
}

test "DominatorTree: recompute clears old tree" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    // First CFG: B0 -> B1 -> B2
    const blocks1 = [_]Block{
        Block.new(0),
        Block.new(1),
        Block.new(2),
    };

    try buildLinearCFG(&cfg, &blocks1);
    try tree.compute(testing.allocator, blocks1[0], &cfg);

    // Verify B1 has idom
    try testing.expect(tree.idominator(blocks1[1]) != null);

    // Clear CFG and create new one: B0 -> B1 (no B2)
    cfg.deinit();
    cfg = CFG.init(testing.allocator);

    try cfg.addEdge(blocks1[0], blocks1[1]);
    try tree.compute(testing.allocator, blocks1[0], &cfg);

    // B2 should no longer be reachable
    try testing.expect(!tree.isReachable(blocks1[2]));
}

test "DominatorTree: complex CFG with multiple paths" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    var tree = DominatorTree.init(testing.allocator);
    defer tree.deinit();

    // Complex CFG:
    //       B0
    //      /  \
    //     B1  B2
    //     |\  /|
    //     | B3 |
    //     |/ \ |
    //     B4  B5
    //      \  /
    //       B6

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

    // B0 dominates all blocks
    try testing.expect(tree.dominates(b0, b1));
    try testing.expect(tree.dominates(b0, b2));
    try testing.expect(tree.dominates(b0, b3));
    try testing.expect(tree.dominates(b0, b4));
    try testing.expect(tree.dominates(b0, b5));
    try testing.expect(tree.dominates(b0, b6));

    // B3 has multiple paths to entry
    try testing.expect(std.meta.eql(tree.idominator(b3).?, b0));

    // Verify tree is valid
    try tree.verify(testing.allocator, b0, &cfg);
}
