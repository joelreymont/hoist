// Control Flow Graph construction and manipulation.
//
// A CFG maps blocks to their predecessors and successors. Predecessors
// are represented as (block, inst) pairs where inst is the terminator.
// Successors are just block IDs.

const std = @import("std");
const entities = @import("entities.zig");
const Block = entities.Block;
const Inst = entities.Inst;
const Function = @import("function.zig").Function;

/// Basic block predecessor: (block, terminator instruction).
pub const BlockPredecessor = struct {
    block: Block,
    inst: Inst,

    pub fn init(block: Block, inst: Inst) BlockPredecessor {
        return .{ .block = block, .inst = inst };
    }
};

/// CFG node containing predecessors and successors for a block.
pub const CFGNode = struct {
    /// Map from terminator instruction to predecessor block.
    predecessors: std.AutoHashMap(Inst, Block),
    /// Set of successor blocks.
    successors: std.AutoHashMap(Block, void),

    pub fn init(allocator: std.mem.Allocator) CFGNode {
        return .{
            .predecessors = std.AutoHashMap(Inst, Block).init(allocator),
            .successors = std.AutoHashMap(Block, void).init(allocator),
        };
    }

    fn deinit(self: *CFGNode, allocator: std.mem.Allocator) void {
        _ = allocator;
        self.predecessors.deinit();
        self.successors.deinit();
    }

    fn clear(self: *CFGNode) void {
        self.predecessors.clearRetainingCapacity();
        self.successors.clearRetainingCapacity();
    }
};

/// Control Flow Graph.
pub const ControlFlowGraph = struct {
    allocator: std.mem.Allocator,
    /// CFG nodes per block (indexed by block number).
    data: std.ArrayList(CFGNode),
    valid: bool,

    pub fn init(allocator: std.mem.Allocator) ControlFlowGraph {
        return .{
            .allocator = allocator,
            .data = .{},
            .valid = false,
        };
    }

    pub fn deinit(self: *ControlFlowGraph, allocator: std.mem.Allocator) void {
        for (self.data.items) |*node| {
            node.deinit(allocator);
        }
        self.data.deinit(allocator);
    }

    pub fn clear(self: *ControlFlowGraph) void {
        for (self.data.items) |*node| {
            node.clear();
        }
        self.data.clearRetainingCapacity();
        self.valid = false;
    }

    /// Compute CFG from function.
    pub fn compute(self: *ControlFlowGraph, func: *const Function) !void {
        self.clear();

        // Resize data to hold all blocks
        const num_blocks = func.dfg.blocks.len();
        try self.data.resize(self.allocator, num_blocks);
        for (0..num_blocks) |i| {
            self.data.items[i] = CFGNode.init(self.allocator);
        }

        // Build edges by visiting all blocks
        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            try self.computeBlock(func, block);
        }

        self.valid = true;
    }

    fn computeBlock(self: *ControlFlowGraph, func: *const Function, block: Block) !void {
        // Visit all branch/jump successors of this block
        const block_data = func.layout.blocks.get(block) orelse return;

        // Get last instruction (terminator)
        if (block_data.last_inst) |last_inst| {
            const inst_data = func.dfg.insts.get(last_inst) orelse return;

            // Extract successor blocks based on instruction type
            switch (inst_data.opcode()) {
                .jump => {
                    try self.addEdge(block, last_inst, inst_data.jump.destination);
                },
                .brif => {
                    if (inst_data.branch.then_dest) |then_dest| {
                        try self.addEdge(block, last_inst, then_dest);
                    }
                    if (inst_data.branch.else_dest) |else_dest| {
                        try self.addEdge(block, last_inst, else_dest);
                    }
                },
                .br_table => {
                    // TODO: Look up jump table destinations from function.jump_tables
                    // For now, skip adding edges for br_table
                },
                else => {}, // Non-branching terminator (return, trap, etc)
            }
        }
    }

    pub fn addEdge(self: *ControlFlowGraph, from: Block, from_inst: Inst, to: Block) !void {
        const from_idx = from.toIndex();
        const to_idx = to.toIndex();

        // Add to successors of 'from'
        try self.data.items[from_idx].successors.put(to, {});

        // Add to predecessors of 'to'
        try self.data.items[to_idx].predecessors.put(from_inst, from);
    }

    /// Invalidate successors of a block (for recomputation).
    fn invalidateBlockSuccessors(self: *ControlFlowGraph, block: Block) void {
        const block_idx = block.toIndex();
        var node = &self.data.items[block_idx];

        // Remove this block from all successors' predecessor lists
        var succ_iter = node.successors.keyIterator();
        while (succ_iter.next()) |succ_block| {
            const succ_idx = succ_block.toIndex();
            var pred_iter = self.data.items[succ_idx].predecessors.iterator();
            while (pred_iter.next()) |entry| {
                if (entry.value_ptr.*.eql(block)) {
                    _ = self.data.items[succ_idx].predecessors.remove(entry.key_ptr.*);
                }
            }
        }

        node.successors.clearRetainingCapacity();
    }

    /// Recompute CFG for a single block (after modifying its terminators).
    pub fn recomputeBlock(self: *ControlFlowGraph, func: *const Function, block: Block) !void {
        std.debug.assert(self.valid);
        self.invalidateBlockSuccessors(block);
        try self.computeBlock(func, block);
    }

    /// Iterator over predecessors.
    pub fn predIter(self: *const ControlFlowGraph, block: Block) PredIterator {
        const block_idx = block.toIndex();
        return PredIterator{
            .inner = self.data.items[block_idx].predecessors.iterator(),
        };
    }

    /// Iterator over predecessors (alias for predIter).
    pub fn predecessors(self: *const ControlFlowGraph, block: Block) PredIterator {
        return self.predIter(block);
    }

    /// Get count of predecessors for a block.
    pub fn predecessorCount(self: *const ControlFlowGraph, block: Block) usize {
        const block_idx = block.toIndex();
        return self.data.items[block_idx].predecessors.count();
    }

    /// Iterator over successors.
    pub fn succIter(self: *const ControlFlowGraph, block: Block) SuccIterator {
        std.debug.assert(self.valid);
        const block_idx = block.toIndex();
        return SuccIterator{
            .inner = self.data.items[block_idx].successors.keyIterator(),
        };
    }

    /// Iterator over successors (alias for succIter).
    pub fn successors(self: *const ControlFlowGraph, block: Block) SuccIterator {
        return self.succIter(block);
    }

    /// Get count of successors for a block.
    pub fn successorCount(self: *const ControlFlowGraph, block: Block) usize {
        std.debug.assert(self.valid);
        const block_idx = block.toIndex();
        return self.data.items[block_idx].successors.count();
    }

    pub fn isValid(self: *const ControlFlowGraph) bool {
        return self.valid;
    }

    /// Check if an edge is critical.
    /// A critical edge is one where:
    /// - The source block has multiple successors, AND
    /// - The target block has multiple predecessors
    pub fn isCriticalEdge(self: *const ControlFlowGraph, from: Block, to: Block) bool {
        const from_idx = from.toIndex();
        const to_idx = to.toIndex();

        const from_succ_count = self.data.items[from_idx].successors.count();
        const to_pred_count = self.data.items[to_idx].predecessors.count();

        return from_succ_count > 1 and to_pred_count > 1;
    }

    /// Split a critical edge by inserting a new block.
    /// Returns the newly created block between 'from' and 'to'.
    /// The caller is responsible for updating the function's DFG and layout.
    pub fn splitCriticalEdge(
        self: *ControlFlowGraph,
        from: Block,
        from_inst: Inst,
        to: Block,
        new_block: Block,
    ) !void {
        std.debug.assert(self.valid);
        std.debug.assert(self.isCriticalEdge(from, to));

        // Ensure new block has space in CFG
        const new_idx = new_block.toIndex();
        if (new_idx >= self.data.items.len) {
            try self.data.resize(new_idx + 1);
            self.data.items[new_idx] = CFGNode.init(self.allocator);
        }

        // Remove edge from -> to
        const from_idx = from.toIndex();
        const to_idx = to.toIndex();

        _ = self.data.items[from_idx].successors.remove(to);
        _ = self.data.items[to_idx].predecessors.remove(from_inst);

        // Add edges: from -> new_block -> to
        try self.data.items[from_idx].successors.put(new_block, {});
        try self.data.items[new_idx].predecessors.put(from_inst, from);

        try self.data.items[new_idx].successors.put(to, {});
        // Note: The caller must create a new terminator instruction for new_block
        // and update from_inst's target from 'to' to 'new_block'
        // We use a placeholder inst here - caller will fix it
        try self.data.items[to_idx].predecessors.put(from_inst, new_block);
    }

    /// Validate CFG consistency.
    /// Returns error if CFG is malformed.
    pub fn validate(self: *const ControlFlowGraph, func: *const Function) !void {
        if (!self.valid) return error.CFGNotComputed;

        // Validate all blocks in layout
        var block_iter = func.layout.blocks();
        while (block_iter.next()) |block| {
            try self.validateBlock(func, block);
        }
    }

    pub fn validateBlock(self: *const ControlFlowGraph, func: *const Function, block: Block) !void {
        const block_data = func.layout.blocks.get(block) orelse return error.BlockNotInLayout;

        // Get last instruction (terminator)
        const last_inst = block_data.last_inst orelse return;
        const inst_data = func.dfg.insts.get(last_inst) orelse return error.InvalidTerminator;

        // Verify successors match terminator targets
        switch (inst_data.opcode()) {
            .jump => {
                try self.validateEdge(block, last_inst, inst_data.jump.destination);
            },
            .brif => {
                const then_dest = inst_data.branch.then_dest orelse return error.MissingBranchTarget;
                const else_dest = inst_data.branch.else_dest orelse return error.MissingBranchTarget;
                try self.validateEdge(block, last_inst, then_dest);
                try self.validateEdge(block, last_inst, else_dest);
            },
            .br_table => {
                // TODO: Validate br_table destinations
                // Jump table destinations are stored in a separate JumpTable entity,
                // requires looking up inst_data.branch_table.destination in function's jump table pool
            },
            else => {}, // Non-branching terminator
        }
    }

    fn validateJump(self: *const ControlFlowGraph, from: Block, inst: Inst, to_opt: ?Block) !void {
        const to = to_opt orelse return error.MissingJumpTarget;
        try self.validateEdge(from, inst, to);
    }

    fn validateEdge(self: *const ControlFlowGraph, from: Block, from_inst: Inst, to: Block) !void {
        const from_idx = from.toIndex();
        const to_idx = to.toIndex();

        // Verify forward edge: from -> to
        if (!self.data.items[from_idx].successors.contains(to)) {
            return error.MissingSuccessorEdge;
        }

        // Verify backward edge: to has from as predecessor
        const pred_block = self.data.items[to_idx].predecessors.get(from_inst) orelse
            return error.MissingPredecessorEdge;

        if (!std.meta.eql(pred_block, from)) {
            return error.InconsistentPredecessor;
        }
    }
};

pub const PredIterator = struct {
    inner: std.AutoHashMap(Inst, Block).Iterator,

    pub fn next(self: *PredIterator) ?BlockPredecessor {
        const entry = self.inner.next() orelse return null;
        return BlockPredecessor{
            .inst = entry.key_ptr.*,
            .block = entry.value_ptr.*,
        };
    }
};

pub const SuccIterator = struct {
    inner: std.AutoHashMap(Block, void).KeyIterator,

    pub fn next(self: *SuccIterator) ?Block {
        return if (self.inner.next()) |key| key.* else null;
    }
};

/// Compute reverse postorder traversal from entry block.
pub fn reversePostorder(allocator: std.mem.Allocator, cfg: *const ControlFlowGraph, entry: Block) ![]Block {
    var visited = std.AutoHashMap(Block, void).init(allocator);
    defer visited.deinit();

    var postorder = std.ArrayList(Block){};
    errdefer postorder.deinit();

    try dfsPostorder(cfg, entry, &visited, &postorder);

    // Reverse to get reverse postorder
    std.mem.reverse(Block, postorder.items);

    return postorder.toOwnedSlice();
}

fn dfsPostorder(
    cfg: *const ControlFlowGraph,
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

// Tests

const testing = std.testing;

test "CFG: basic construction" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit(testing.allocator);

    try testing.expect(!cfg.isValid());
    cfg.clear();
    try testing.expect(!cfg.isValid());
}
