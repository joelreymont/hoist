const std = @import("std");
const testing = std.testing;

const root = @import("root");
const cfg_mod = @import("../src/ir/cfg.zig");
const ControlFlowGraph = cfg_mod.ControlFlowGraph;
const BlockPredecessor = cfg_mod.BlockPredecessor;

// Test: CFG basic construction

test "CFG: initialization and cleanup" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit();

    try testing.expect(!cfg.isValid());
}

test "CFG: clear invalidates graph" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit();

    cfg.clear();
    try testing.expect(!cfg.isValid());
}

// Test: CFG edge management

test "CFG: basic edge addition" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit();

    // Create simple two-block CFG with one edge
    // Block 0 -> Block 1
    const block0 = root.entities.Block.new(0);
    const block1 = root.entities.Block.new(1);
    const inst0 = root.entities.Inst.new(0);

    // Simulate basic setup
    try cfg.data.resize(2);
    for (0..2) |i| {
        cfg.data.items[i] = cfg_mod.CFGNode.init(testing.allocator);
    }

    try cfg.addEdge(block0, inst0, block1);

    // Verify edge was added
    var succ_iter = cfg.succIter(block0);
    const succ = succ_iter.next();
    try testing.expect(succ != null);
    try testing.expect(succ.?.eql(block1));

    var pred_iter = cfg.predIter(block1);
    const pred = pred_iter.next();
    try testing.expect(pred != null);
    try testing.expect(pred.?.block.eql(block0));
    try testing.expect(pred.?.inst.eql(inst0));
}

test "CFG: multiple successors" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit();

    // Block 0 branches to Block 1 and Block 2
    const block0 = root.entities.Block.new(0);
    const block1 = root.entities.Block.new(1);
    const block2 = root.entities.Block.new(2);
    const inst0 = root.entities.Inst.new(0);

    try cfg.data.resize(3);
    for (0..3) |i| {
        cfg.data.items[i] = cfg_mod.CFGNode.init(testing.allocator);
    }

    try cfg.addEdge(block0, inst0, block1);
    try cfg.addEdge(block0, inst0, block2);

    // Count successors
    var count: usize = 0;
    var succ_iter = cfg.succIter(block0);
    while (succ_iter.next()) |_| {
        count += 1;
    }
    try testing.expectEqual(@as(usize, 2), count);
}

test "CFG: multiple predecessors" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit();

    // Block 0 and Block 1 both jump to Block 2
    const block0 = root.entities.Block.new(0);
    const block1 = root.entities.Block.new(1);
    const block2 = root.entities.Block.new(2);
    const inst0 = root.entities.Inst.new(0);
    const inst1 = root.entities.Inst.new(1);

    try cfg.data.resize(3);
    for (0..3) |i| {
        cfg.data.items[i] = cfg_mod.CFGNode.init(testing.allocator);
    }

    try cfg.addEdge(block0, inst0, block2);
    try cfg.addEdge(block1, inst1, block2);

    // Count predecessors
    var count: usize = 0;
    var pred_iter = cfg.predIter(block2);
    while (pred_iter.next()) |_| {
        count += 1;
    }
    try testing.expectEqual(@as(usize, 2), count);
}

// Test: CFG diamond pattern

test "CFG: diamond control flow" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit();

    // Diamond pattern:
    //     B0
    //    /  \
    //   B1  B2
    //    \  /
    //     B3

    const b0 = root.entities.Block.new(0);
    const b1 = root.entities.Block.new(1);
    const b2 = root.entities.Block.new(2);
    const b3 = root.entities.Block.new(3);

    const i0 = root.entities.Inst.new(0);
    const i1 = root.entities.Inst.new(1);
    const i2 = root.entities.Inst.new(2);

    try cfg.data.resize(4);
    for (0..4) |i| {
        cfg.data.items[i] = cfg_mod.CFGNode.init(testing.allocator);
    }

    // B0 -> B1, B2
    try cfg.addEdge(b0, i0, b1);
    try cfg.addEdge(b0, i0, b2);

    // B1 -> B3
    try cfg.addEdge(b1, i1, b3);

    // B2 -> B3
    try cfg.addEdge(b2, i2, b3);

    // Verify B0 has 2 successors
    var b0_succs: usize = 0;
    var s0 = cfg.succIter(b0);
    while (s0.next()) |_| b0_succs += 1;
    try testing.expectEqual(@as(usize, 2), b0_succs);

    // Verify B3 has 2 predecessors
    var b3_preds: usize = 0;
    var p3 = cfg.predIter(b3);
    while (p3.next()) |_| b3_preds += 1;
    try testing.expectEqual(@as(usize, 2), b3_preds);
}

// Test: CFG loop pattern

test "CFG: simple loop" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit();

    // Simple loop:
    //   B0 -> B1 -> B2
    //         ^      |
    //         |______|

    const b0 = root.entities.Block.new(0);
    const b1 = root.entities.Block.new(1);
    const b2 = root.entities.Block.new(2);

    const i0 = root.entities.Inst.new(0);
    const i1 = root.entities.Inst.new(1);
    const i2 = root.entities.Inst.new(2);

    try cfg.data.resize(3);
    for (0..3) |i| {
        cfg.data.items[i] = cfg_mod.CFGNode.init(testing.allocator);
    }

    try cfg.addEdge(b0, i0, b1);
    try cfg.addEdge(b1, i1, b2);
    try cfg.addEdge(b2, i2, b1); // Back edge

    // B1 should have 2 predecessors (B0 and B2)
    var b1_preds: usize = 0;
    var p1 = cfg.predIter(b1);
    while (p1.next()) |_| b1_preds += 1;
    try testing.expectEqual(@as(usize, 2), b1_preds);
}

// Test: CFG invalidation and recomputation

test "CFG: invalidate block successors" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit();

    const b0 = root.entities.Block.new(0);
    const b1 = root.entities.Block.new(1);
    const i0 = root.entities.Inst.new(0);

    try cfg.data.resize(2);
    for (0..2) |i| {
        cfg.data.items[i] = cfg_mod.CFGNode.init(testing.allocator);
    }

    try cfg.addEdge(b0, i0, b1);

    // Verify edge exists
    var succ_before = cfg.succIter(b0);
    try testing.expect(succ_before.next() != null);

    // Invalidate B0's successors
    cfg.invalidateBlockSuccessors(b0);

    // Verify successors cleared
    var succ_after = cfg.succIter(b0);
    try testing.expect(succ_after.next() == null);
}

// Test: CFG validation

test "CFG: validation passes for valid CFG" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit();

    var func = root.ir.Function.init(testing.allocator);
    defer func.deinit();

    // Create simple two-block CFG
    const b0 = try func.dfg.blocks.add();
    const b1 = try func.dfg.blocks.add();

    // Add blocks to layout
    try func.layout.appendBlock(b0);
    try func.layout.appendBlock(b1);

    // Create jump from b0 to b1
    const jump_data = root.ir.InstructionData{
        .jump = .{ .opcode = .jump, .destination = b1 },
    };
    const jump_inst = try func.dfg.makeInst(jump_data);
    try func.layout.appendInst(jump_inst, b0);

    // Compute CFG
    try cfg.compute(&func);
    try testing.expect(cfg.isValid());

    // Validate - should pass
    try cfg.validate(&func);
}

test "CFG: validation detects missing edge" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit();

    // Manually create inconsistent CFG
    const b0 = root.entities.Block.new(0);
    const b1 = root.entities.Block.new(1);
    const i0 = root.entities.Inst.new(0);

    try cfg.data.resize(2);
    for (0..2) |i| {
        cfg.data.items[i] = cfg_mod.CFGNode.init(testing.allocator);
    }

    // Add successor but not predecessor (inconsistent!)
    try cfg.data.items[0].successors.put(b1, {});
    cfg.valid = true;

    // Create minimal function for validation
    var func = root.ir.Function.init(testing.allocator);
    defer func.deinit();

    const block0 = try func.dfg.blocks.add();
    const block1 = try func.dfg.blocks.add();
    try func.layout.appendBlock(block0);
    try func.layout.appendBlock(block1);

    const jump_data = root.ir.InstructionData{
        .jump = .{ .opcode = .jump, .destination = block1 },
    };
    const jump_inst = try func.dfg.makeInst(jump_data);
    try func.layout.appendInst(jump_inst, block0);

    // Validation should detect inconsistency
    const result = cfg.validate(&func);
    try testing.expectError(error.MissingPredecessorEdge, result);
}

test "CFG: critical edge detection" {
    var cfg = ControlFlowGraph.init(testing.allocator);
    defer cfg.deinit();

    // Diamond with critical edges:
    //     B0
    //    /  \
    //   B1  B2
    //    \  /
    //     B3
    const b0 = root.entities.Block.new(0);
    const b1 = root.entities.Block.new(1);
    const b2 = root.entities.Block.new(2);
    const b3 = root.entities.Block.new(3);

    const i0 = root.entities.Inst.new(0);
    const i1 = root.entities.Inst.new(1);
    const i2 = root.entities.Inst.new(2);

    try cfg.data.resize(4);
    for (0..4) |i| {
        cfg.data.items[i] = cfg_mod.CFGNode.init(testing.allocator);
    }

    // Build diamond
    try cfg.addEdge(b0, i0, b1);
    try cfg.addEdge(b0, i0, b2);
    try cfg.addEdge(b1, i1, b3);
    try cfg.addEdge(b2, i2, b3);
    cfg.valid = true;

    // B1 -> B3 is critical (B1 has 1 succ, but B3 has 2 preds - NOT critical)
    try testing.expect(!cfg.isCriticalEdge(b1, b3));

    // Add another edge to make B1 have multiple successors
    const b4 = root.entities.Block.new(4);
    try cfg.data.resize(5);
    cfg.data.items[4] = cfg_mod.CFGNode.init(testing.allocator);
    try cfg.addEdge(b1, i1, b4);

    // Now B1 -> B3 is critical (B1 has 2 succs, B3 has 2 preds)
    try testing.expect(cfg.isCriticalEdge(b1, b3));
}
