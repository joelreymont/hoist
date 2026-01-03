const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const ir_mod = @import("../ir.zig");
const Block = ir_mod.Block;
const DominatorTree = @import("domtree.zig").DominatorTree;
const CFG = @import("domtree.zig").CFG;

/// Natural loop information.
pub const Loop = struct {
    /// Loop header block (dominates all blocks in loop).
    header: Block,

    /// Blocks that are part of this loop.
    blocks: std.ArrayList(Block),

    /// Loop depth (0 for top-level loops).
    depth: u32,

    /// Parent loop (if this is a nested loop).
    parent: ?*Loop,

    /// Allocator.
    allocator: Allocator,

    pub fn init(allocator: Allocator, header: Block, depth: u32) Loop {
        return .{
            .header = header,
            .blocks = std.ArrayList(Block){},
            .depth = depth,
            .parent = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Loop) void {
        self.blocks.deinit();
    }

    /// Check if block is in this loop.
    pub fn contains(self: *const Loop, block: Block) bool {
        for (self.blocks.items) |b| {
            if (std.meta.eql(b, block)) return true;
        }
        return false;
    }

    /// Add block to loop.
    pub fn addBlock(self: *Loop, block: Block) !void {
        if (!self.contains(block)) {
            try self.blocks.append(self.allocator, block);
        }
    }
};

/// Loop forest - all loops in a function.
pub const LoopInfo = struct {
    /// All discovered loops.
    loops: std.ArrayList(*Loop),

    /// Map from block to innermost loop containing it.
    block_to_loop: std.AutoHashMap(Block, *Loop),

    /// Allocator.
    allocator: Allocator,

    pub fn init(allocator: Allocator) LoopInfo {
        return .{
            .loops = std.ArrayList(*Loop){},
            .block_to_loop = std.AutoHashMap(Block, *Loop).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LoopInfo, allocator: std.mem.Allocator) void {
        _ = allocator;
        for (self.loops.items) |loop| {
            loop.deinit();
            self.allocator.destroy(loop);
        }
        self.loops.deinit();
        self.block_to_loop.deinit();
    }

    /// Compute loop information using dominator tree.
    /// Identifies natural loops via back edges (edges to dominators).
    pub fn compute(
        self: *LoopInfo,
        cfg: *const CFG,
        domtree: *const DominatorTree,
    ) !void {
        // Find all back edges (edges from a block to one of its dominators)
        var back_edges = std.ArrayList(struct { from: Block, to: Block }).init(self.allocator);
        defer back_edges.deinit();

        // Iterate through CFG edges
        var iter = cfg.succs.iterator();
        while (iter.next()) |entry| {
            const from = entry.key_ptr.*;
            const succs = entry.value_ptr.*;

            for (succs.items) |to| {
                // If 'to' dominates 'from', this is a back edge
                if (domtree.dominates(to, from)) {
                    try back_edges.append(.{ .from = from, .to = to });
                }
            }
        }

        // Create a loop for each back edge
        for (back_edges.items) |edge| {
            try self.createLoop(edge.to, edge.from, cfg, domtree);
        }
    }

    /// Create loop with given header and back edge source.
    fn createLoop(
        self: *LoopInfo,
        header: Block,
        back_edge_src: Block,
        cfg: *const CFG,
        domtree: *const DominatorTree,
    ) !void {
        // Create new loop
        const loop = try self.allocator.create(Loop);
        loop.* = Loop.init(self.allocator, header, 0);

        try loop.addBlock(header);

        // Find all blocks in the loop using worklist algorithm
        var worklist = std.ArrayList(Block).init(self.allocator);
        defer worklist.deinit();

        try worklist.append(back_edge_src);
        try loop.addBlock(back_edge_src);

        while (worklist.items.len > 0) {
            const block = worklist.pop();

            // Add all predecessors that are dominated by the header
            const preds = cfg.predecessors(block);
            for (preds) |pred| {
                if (domtree.dominates(header, pred) and !loop.contains(pred)) {
                    try loop.addBlock(pred);
                    try worklist.append(pred);
                }
            }
        }

        // Add loop to forest
        try self.loops.append(loop);

        // Map blocks to their innermost loop
        for (loop.blocks.items) |block| {
            try self.block_to_loop.put(block, loop);
        }
    }

    /// Get the innermost loop containing a block.
    pub fn getLoop(self: *const LoopInfo, block: Block) ?*Loop {
        return self.block_to_loop.get(block);
    }

    /// Get loop depth of a block.
    pub fn loopDepth(self: *const LoopInfo, block: Block) u32 {
        if (self.getLoop(block)) |loop| {
            return loop.depth;
        }
        return 0;
    }

    /// Check if block is a loop header.
    pub fn isLoopHeader(self: *const LoopInfo, block: Block) bool {
        for (self.loops.items) |loop| {
            if (std.meta.eql(loop.header, block)) return true;
        }
        return false;
    }
};

test "Loop basic" {
    const b0 = Block.new(0);
    var loop = Loop.init(testing.allocator, b0, 0);
    defer loop.deinit();

    try loop.addBlock(b0);
    try testing.expect(loop.contains(b0));

    const b1 = Block.new(1);
    try testing.expect(!loop.contains(b1));

    try loop.addBlock(b1);
    try testing.expect(loop.contains(b1));
}

test "LoopInfo basic" {
    var loop_info = LoopInfo.init(testing.allocator);
    defer loop_info.deinit(testing.allocator);

    // Create simple CFG with loop: b0 -> b1 -> b2 -> b1
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b1, b2);
    try cfg.addEdge(b2, b1); // Back edge

    // Create dominator tree
    var domtree = DominatorTree.init(testing.allocator);
    defer domtree.deinit();

    try domtree.idom.set(testing.allocator, b0, null); // Entry
    try domtree.idom.set(testing.allocator, b1, b0);
    try domtree.idom.set(testing.allocator, b2, b1);

    // Compute loops
    try loop_info.compute(&cfg, &domtree);

    // Should find one loop with header b1
    try testing.expectEqual(@as(usize, 1), loop_info.loops.items.len);

    const loop = loop_info.loops.items[0];
    try testing.expect(std.meta.eql(loop.header, b1));

    // Loop should contain b1 and b2
    try testing.expect(loop.contains(b1));
    try testing.expect(loop.contains(b2));

    // b0 is not in the loop
    try testing.expect(!loop.contains(b0));

    // b1 is a loop header
    try testing.expect(loop_info.isLoopHeader(b1));
    try testing.expect(!loop_info.isLoopHeader(b0));
}

test "LoopInfo nested loops" {
    var loop_info = LoopInfo.init(testing.allocator);
    defer loop_info.deinit(testing.allocator);

    // We would need a more complex CFG for nested loops
    // This is a placeholder test
    try testing.expectEqual(@as(usize, 0), loop_info.loops.items.len);
}
