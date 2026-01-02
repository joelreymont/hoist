//! Unreachable Code Elimination (UCE) optimization pass.
//!
//! Removes unreachable code from functions:
//! - Blocks unreachable from the entry block
//! - Instructions after terminators within a block
//!
//! This is a forward reachability analysis that marks reachable blocks
//! from the entry block using the CFG, then removes unmarked blocks
//! and instructions after terminators.

const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("root");
const Function = root.function.Function;
const Block = root.entities.Block;
const Inst = root.entities.Inst;
const Opcode = root.opcodes.Opcode;
const ControlFlowGraph = root.cfg.ControlFlowGraph;

/// Unreachable code elimination pass.
pub const UCE = struct {
    /// Allocator for temporary data structures.
    allocator: Allocator,
    /// Set of reachable blocks.
    reachable: std.AutoHashMap(Block, void),
    /// Worklist for reachability analysis.
    worklist: std.ArrayList(Block),

    pub fn init(allocator: Allocator) UCE {
        return .{
            .allocator = allocator,
            .reachable = std.AutoHashMap(Block, void).init(allocator),
            .worklist = std.ArrayList(Block).init(allocator),
        };
    }

    pub fn deinit(self: *UCE) void {
        self.reachable.deinit();
        self.worklist.deinit();
    }

    /// Run UCE on the function.
    /// Returns true if any code was removed.
    pub fn run(self: *UCE, func: *Function) !bool {
        // Build CFG for successor analysis
        var cfg = ControlFlowGraph.init(self.allocator);
        defer cfg.deinit();
        try cfg.compute(func);

        // Mark reachable blocks from entry
        try self.markReachable(func, &cfg);

        // Remove unreachable blocks and instructions
        const removed_blocks = try self.removeUnreachableBlocks(func);
        const removed_insts = try self.removeDeadInsts(func);

        // Clear for next run
        self.reachable.clearRetainingCapacity();
        self.worklist.clearRetainingCapacity();

        return removed_blocks or removed_insts;
    }

    /// Mark all reachable blocks from entry using BFS.
    fn markReachable(self: *UCE, func: *Function, cfg: *const ControlFlowGraph) !void {
        const entry = func.entryBlock() orelse return;

        // Start with entry block
        try self.worklist.append(entry);
        try self.reachable.put(entry, {});

        // BFS through CFG
        while (self.worklist.items.len > 0) {
            const block = self.worklist.pop();

            // Visit all successors
            var succ_iter = cfg.succIter(block);
            while (succ_iter.next()) |succ| {
                if (!self.reachable.contains(succ)) {
                    try self.reachable.put(succ, {});
                    try self.worklist.append(succ);
                }
            }
        }
    }

    /// Remove unreachable blocks from the function.
    fn removeUnreachableBlocks(self: *UCE, func: *Function) !bool {
        var removed = false;
        var dead_blocks = std.ArrayList(Block).init(self.allocator);
        defer dead_blocks.deinit();

        // Collect unreachable blocks
        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            if (!self.reachable.contains(block)) {
                try dead_blocks.append(block);
            }
        }

        // Remove unreachable blocks from layout
        for (dead_blocks.items) |block| {
            func.layout.removeBlock(block);
            removed = true;
        }

        return removed;
    }

    /// Remove instructions after terminators within blocks.
    fn removeDeadInsts(self: *UCE, func: *Function) !bool {
        var removed = false;
        var dead_insts = std.ArrayList(Inst).init(self.allocator);
        defer dead_insts.deinit();

        // Check each reachable block for dead instructions
        var block_iter = func.layout.blockIter();
        while (block_iter.next()) |block| {
            if (!self.reachable.contains(block)) continue;

            var found_terminator = false;
            var inst_iter = func.layout.blockInsts(block);
            while (inst_iter.next()) |inst| {
                if (found_terminator) {
                    // Instruction after terminator - unreachable
                    try dead_insts.append(inst);
                } else {
                    const inst_data = func.dfg.insts.get(inst) orelse continue;
                    if (self.isTerminator(inst_data.opcode())) {
                        found_terminator = true;
                    }
                }
            }
        }

        // Remove dead instructions
        for (dead_insts.items) |inst| {
            func.layout.removeInst(inst);
            removed = true;
        }

        return removed;
    }

    /// Check if an opcode is a terminator instruction.
    fn isTerminator(self: *UCE, opcode: Opcode) bool {
        _ = self;
        return switch (opcode) {
            .jump, .brif, .br_table, .@"return" => true,
            .trap, .trapz, .trapnz, .debugtrap => true,
            .return_call, .return_call_indirect => true,
            else => false,
        };
    }
};

// Tests

const testing = std.testing;

test "UCE: isTerminator" {
    var uce = UCE.init(testing.allocator);
    defer uce.deinit();

    // Control flow terminators
    try testing.expect(uce.isTerminator(.jump));
    try testing.expect(uce.isTerminator(.brif));
    try testing.expect(uce.isTerminator(.br_table));
    try testing.expect(uce.isTerminator(.@"return"));
    try testing.expect(uce.isTerminator(.trap));

    // Non-terminators
    try testing.expect(!uce.isTerminator(.iadd));
    try testing.expect(!uce.isTerminator(.call));
    try testing.expect(!uce.isTerminator(.store));
}
