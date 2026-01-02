const std = @import("std");
const testing = std.testing;

const root = @import("../root.zig");
const ir = @import("../ir.zig");
const Function = ir.Function;
const Signature = root.signature.Signature;
const Block = root.entities.Block;
const Inst = root.entities.Inst;
const Value = root.entities.Value;
const Type = root.types.Type;
const InstructionData = ir.InstructionData;
const ValueData = @import("dfg.zig").ValueData;
const ValueDef = @import("dfg.zig").ValueDef;
const DominatorTree = @import("domtree.zig").DominatorTree;
const CFG = @import("domtree.zig").CFG;

// SSA Construction Tests
//
// These tests verify SSA (Static Single Assignment) form properties:
// - Phi node insertion at dominance frontiers
// - Variable renaming to ensure single assignment
// - SSA form verification
// - Dominance frontier computation

// Test: SSA form verification - basic linear code

test "SSA: linear code in SSA form" {
    const sig = try Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    // Create simple linear code:
    // b0:
    //   v0 = const 42
    //   v1 = const 10
    //   v2 = iadd v0, v1
    //   ret v2

    const b0 = try func.dfg.blocks.add();
    try func.layout.appendBlock(b0);

    // v0 = const 42
    const const42_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 42 } };
    const const42_inst = try func.dfg.makeInst(const42_data);
    try func.layout.appendInst(const42_inst, b0);
    const v0 = try func.dfg.appendInstResult(const42_inst, Type.I32);

    // v1 = const 10
    const const10_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 10 } };
    const const10_inst = try func.dfg.makeInst(const10_data);
    try func.layout.appendInst(const10_inst, b0);
    const v1 = try func.dfg.appendInstResult(const10_inst, Type.I32);

    // v2 = iadd v0, v1
    const iadd_data = InstructionData{ .binary = .{
        .opcode = .iadd,
        .args = [2]Value{ v0, v1 },
    } };
    const iadd_inst = try func.dfg.makeInst(iadd_data);
    try func.layout.appendInst(iadd_inst, b0);
    const v2 = try func.dfg.appendInstResult(iadd_inst, Type.I32);

    // ret v2
    const ret_data = InstructionData{ .unary = .{ .opcode = .@"return", .arg = v2 } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, b0);

    // Verify SSA properties:
    // 1. Each value has exactly one definition
    try testing.expectEqual(@as(usize, 1), func.dfg.numResults(const42_inst));
    try testing.expectEqual(@as(usize, 1), func.dfg.numResults(const10_inst));
    try testing.expectEqual(@as(usize, 1), func.dfg.numResults(iadd_inst));

    // 2. Value definitions are unique
    try testing.expect(!std.meta.eql(v0, v1));
    try testing.expect(!std.meta.eql(v1, v2));
    try testing.expect(!std.meta.eql(v0, v2));

    // 3. Each value has correct type
    try testing.expectEqual(Type.I32, func.dfg.valueType(v0).?);
    try testing.expectEqual(Type.I32, func.dfg.valueType(v1).?);
    try testing.expectEqual(Type.I32, func.dfg.valueType(v2).?);
}

// Test: Block parameters as phi nodes

test "SSA: block parameters represent phi nodes" {
    const sig = try Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    // Create diamond CFG with phi:
    // b0:
    //   v0 = const 1
    //   v1 = const 2
    //   br_if v0, b1, b2
    // b1:
    //   v2 = const 10
    //   jump b3(v2)
    // b2:
    //   v3 = const 20
    //   jump b3(v3)
    // b3(v4):  <- v4 is phi(v2, v3)
    //   ret v4

    const b0 = try func.dfg.blocks.add();
    const b1 = try func.dfg.blocks.add();
    const b2 = try func.dfg.blocks.add();
    const b3 = try func.dfg.blocks.add();

    try func.layout.appendBlock(b0);
    try func.layout.appendBlock(b1);
    try func.layout.appendBlock(b2);
    try func.layout.appendBlock(b3);

    // Block b0
    const const1_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 1 } };
    const const1_inst = try func.dfg.makeInst(const1_data);
    try func.layout.appendInst(const1_inst, b0);
    _ = try func.dfg.appendInstResult(const1_inst, Type.I32);

    const const2_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 2 } };
    const const2_inst = try func.dfg.makeInst(const2_data);
    try func.layout.appendInst(const2_inst, b0);
    _ = try func.dfg.appendInstResult(const2_inst, Type.I32);

    // Create branch (simplified - using jump as placeholder)
    const jump_b1_data = InstructionData{ .jump = .{ .opcode = .jump, .destination = b1 } };
    const jump_b1_inst = try func.dfg.makeInst(jump_b1_data);
    try func.layout.appendInst(jump_b1_inst, b0);

    // Block b1
    const const10_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 10 } };
    const const10_inst = try func.dfg.makeInst(const10_data);
    try func.layout.appendInst(const10_inst, b1);
    _ = try func.dfg.appendInstResult(const10_inst, Type.I32);

    const jump_b3_from_b1_data = InstructionData{ .jump = .{ .opcode = .jump, .destination = b3 } };
    const jump_b3_from_b1_inst = try func.dfg.makeInst(jump_b3_from_b1_data);
    try func.layout.appendInst(jump_b3_from_b1_inst, b1);

    // Block b2
    const const20_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 20 } };
    const const20_inst = try func.dfg.makeInst(const20_data);
    try func.layout.appendInst(const20_inst, b2);
    _ = try func.dfg.appendInstResult(const20_inst, Type.I32);

    const jump_b3_from_b2_data = InstructionData{ .jump = .{ .opcode = .jump, .destination = b3 } };
    const jump_b3_from_b2_inst = try func.dfg.makeInst(jump_b3_from_b2_data);
    try func.layout.appendInst(jump_b3_from_b2_inst, b2);

    // Block b3 with parameter v4 (phi node)
    var b3_data = try func.dfg.blocks.getOrDefault(b3);
    const v4_index = func.dfg.values.elems.items.len;
    const v4 = Value.new(v4_index);
    const v4_data = try func.dfg.values.getOrDefault(v4);
    v4_data.* = ValueData.param(Type.I32, 0, b3);
    try func.dfg.value_lists.push(&b3_data.params, v4);

    const ret_data = InstructionData{ .unary = .{ .opcode = .@"return", .arg = v4 } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, b3);

    // Verify block parameter
    const params = b3_data.getParams(&func.dfg.value_lists);
    try testing.expectEqual(@as(usize, 1), params.len);
    try testing.expect(std.meta.eql(v4, params[0]));

    // Verify v4 is defined as block parameter
    const v4_def = func.dfg.valueDef(v4).?;
    try testing.expect(std.meta.eql(v4_def.param.block, b3));
    try testing.expectEqual(@as(usize, 0), v4_def.param.index);
}

// Test: Dominance frontier computation

test "SSA: dominance frontier for diamond CFG" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    // Diamond CFG:
    //     b0
    //    /  \
    //   b1  b2
    //    \  /
    //     b3

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b0, b2);
    try cfg.addEdge(b1, b3);
    try cfg.addEdge(b2, b3);

    // Build dominator tree
    var domtree = DominatorTree.init(testing.allocator);
    defer domtree.deinit();
    try domtree.compute(testing.allocator, b0, &cfg);

    // Verify dominance relationships
    try testing.expect(domtree.dominates(b0, b0));
    try testing.expect(domtree.dominates(b0, b1));
    try testing.expect(domtree.dominates(b0, b2));
    try testing.expect(domtree.dominates(b0, b3));
    try testing.expect(!domtree.dominates(b1, b2));
    try testing.expect(!domtree.dominates(b2, b1));
    try testing.expect(!domtree.dominates(b1, b3));
    try testing.expect(!domtree.dominates(b2, b3));

    // Compute dominance frontiers
    // DF(b0) = {} (entry dominates everything)
    // DF(b1) = {b3} (b1 dominates predecessor of b3 but not b3 itself)
    // DF(b2) = {b3}
    // DF(b3) = {}

    const df_b0 = try domtree.dominanceFrontier(testing.allocator, b0, &cfg);
    defer df_b0.deinit();
    try testing.expectEqual(@as(usize, 0), df_b0.items.len);

    const df_b1 = try domtree.dominanceFrontier(testing.allocator, b1, &cfg);
    defer df_b1.deinit();
    try testing.expectEqual(@as(usize, 1), df_b1.items.len);
    try testing.expect(std.meta.eql(b3, df_b1.items[0]));

    const df_b2 = try domtree.dominanceFrontier(testing.allocator, b2, &cfg);
    defer df_b2.deinit();
    try testing.expectEqual(@as(usize, 1), df_b2.items.len);
    try testing.expect(std.meta.eql(b3, df_b2.items[0]));

    const df_b3 = try domtree.dominanceFrontier(testing.allocator, b3, &cfg);
    defer df_b3.deinit();
    try testing.expectEqual(@as(usize, 0), df_b3.items.len);
}

// Test: Dominance frontier for loop

test "SSA: dominance frontier for loop" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    // Loop CFG:
    //   b0 -> b1 -> b2
    //         ^      |
    //         |______|

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b1, b2);
    try cfg.addEdge(b2, b1); // Back edge

    var domtree = DominatorTree.init(testing.allocator);
    defer domtree.deinit();
    try domtree.compute(testing.allocator, b0, &cfg);

    // Verify dominance
    try testing.expect(domtree.dominates(b0, b1));
    try testing.expect(domtree.dominates(b0, b2));
    try testing.expect(domtree.dominates(b1, b2));
    try testing.expect(!domtree.dominates(b2, b1));

    // DF(b0) = {}
    // DF(b1) = {}
    // DF(b2) = {b1} (b2 dominates itself, and b1 has multiple predecessors)

    const df_b2 = try domtree.dominanceFrontier(testing.allocator, b2, &cfg);
    defer df_b2.deinit();
    try testing.expectEqual(@as(usize, 1), df_b2.items.len);
    try testing.expect(std.meta.eql(b1, df_b2.items[0]));
}

// Test: Variable renaming using VRegRenameMap

test "SSA: variable renaming with VRegRenameMap" {
    const VRegRenameMap = @import("../machinst/vcode.zig").VRegRenameMap;
    const VReg = @import("../machinst/reg.zig").VReg;

    var rename_map = VRegRenameMap.init(testing.allocator);
    defer rename_map.deinit();

    // Simulate SSA renaming:
    // Original: x (vreg 0)
    // After b1: x1 (vreg 1)
    // After b2: x2 (vreg 2)

    const x = VReg.new(0, .int);
    const x1 = VReg.new(1, .int);
    const x2 = VReg.new(2, .int);

    // First definition in b1
    try rename_map.addRename(x, x1);
    try testing.expectEqual(@as(u32, 1), rename_map.getRename(x).index());

    // Second definition in b2 (creates new version)
    try rename_map.addRename(x1, x2);
    try testing.expectEqual(@as(u32, 2), rename_map.getRename(x1).index());

    // Original x maps to x1
    try testing.expectEqual(@as(u32, 1), rename_map.getRename(x).index());
}

// Test: SSA verification catches use-before-def

test "SSA: verifier catches use before definition" {
    const sig = try Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const b0 = try func.dfg.blocks.add();
    try func.layout.appendBlock(b0);

    // Create invalid SSA: use v0 before it's defined
    const invalid_v0 = Value.new(999); // Non-existent value

    // Try to use it in iadd
    const iadd_data = InstructionData{ .binary = .{
        .opcode = .iadd,
        .args = [2]Value{ invalid_v0, invalid_v0 },
    } };
    const iadd_inst = try func.dfg.makeInst(iadd_data);
    try func.layout.appendInst(iadd_inst, b0);

    // Verifier should catch this
    const Verifier = @import("verifier.zig").Verifier;
    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();

    const result = verifier.verifySSA();
    try testing.expectError(error.UseBeforeDef, result);
}

// Test: Constant phi removal

test "SSA: constant phi removal optimization" {
    const sig = try Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    // Create CFG where all paths to b3 pass same constant:
    // b0:
    //   v0 = const 42
    //   jump b1
    // b1:
    //   jump b3(v0)
    // b2:
    //   jump b3(v0)
    // b3(v1):  <- v1 should be replaced with alias to v0
    //   ret v1

    const b0 = try func.dfg.blocks.add();
    const b1 = try func.dfg.blocks.add();
    const b2 = try func.dfg.blocks.add();
    const b3 = try func.dfg.blocks.add();

    try func.layout.appendBlock(b0);
    try func.layout.appendBlock(b1);
    try func.layout.appendBlock(b2);
    try func.layout.appendBlock(b3);

    // b0: v0 = const 42
    const const42_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 42 } };
    const const42_inst = try func.dfg.makeInst(const42_data);
    try func.layout.appendInst(const42_inst, b0);
    const v0 = try func.dfg.appendInstResult(const42_inst, Type.I32);

    const jump_b1_data = InstructionData{ .jump = .{ .opcode = .jump, .destination = b1 } };
    const jump_b1_inst = try func.dfg.makeInst(jump_b1_data);
    try func.layout.appendInst(jump_b1_inst, b0);

    // b1: jump b3
    const jump_b3_from_b1_data = InstructionData{ .jump = .{ .opcode = .jump, .destination = b3 } };
    const jump_b3_from_b1_inst = try func.dfg.makeInst(jump_b3_from_b1_data);
    try func.layout.appendInst(jump_b3_from_b1_inst, b1);

    // b2: jump b3
    const jump_b3_from_b2_data = InstructionData{ .jump = .{ .opcode = .jump, .destination = b3 } };
    const jump_b3_from_b2_inst = try func.dfg.makeInst(jump_b3_from_b2_data);
    try func.layout.appendInst(jump_b3_from_b2_inst, b2);

    // b3 with parameter v1
    var b3_data = try func.dfg.blocks.getOrDefault(b3);
    const v1_index = func.dfg.values.elems.items.len;
    const v1 = Value.new(v1_index);
    const v1_data = try func.dfg.values.getOrDefault(v1);
    v1_data.* = ValueData.param(Type.I32, 0, b3);
    try func.dfg.value_lists.push(&b3_data.params, v1);

    // After constant phi removal, v1 should become an alias to v0
    // This is tested in the compile.zig optimization pass
    // Here we verify the alias mechanism works

    // Manually create alias
    v1_data.* = ValueData.alias(Type.I32, v0);
    try testing.expect(v1_data.isAlias());
    try testing.expect(std.meta.eql(v0, v1_data.aliasOriginal().?));

    // Resolve aliases
    const resolved = func.dfg.resolveAliases(v1);
    try testing.expect(std.meta.eql(v0, resolved));
}

// Test: Multiple block parameters (multiple phi nodes)

test "SSA: multiple block parameters in same block" {
    const sig = try Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    // b0:
    //   v0 = const 1
    //   v1 = const 2
    //   jump b2(v0, v1)
    // b1:
    //   v2 = const 3
    //   v3 = const 4
    //   jump b2(v2, v3)
    // b2(v4, v5):  <- two phi nodes
    //   v6 = iadd v4, v5
    //   ret v6

    const b0 = try func.dfg.blocks.add();
    const b1 = try func.dfg.blocks.add();
    const b2 = try func.dfg.blocks.add();

    try func.layout.appendBlock(b0);
    try func.layout.appendBlock(b1);
    try func.layout.appendBlock(b2);

    // b0
    const const1_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 1 } };
    const const1_inst = try func.dfg.makeInst(const1_data);
    try func.layout.appendInst(const1_inst, b0);
    _ = try func.dfg.appendInstResult(const1_inst, Type.I32);

    const const2_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 2 } };
    const const2_inst = try func.dfg.makeInst(const2_data);
    try func.layout.appendInst(const2_inst, b0);
    _ = try func.dfg.appendInstResult(const2_inst, Type.I32);

    const jump_b2_from_b0_data = InstructionData{ .jump = .{ .opcode = .jump, .destination = b2 } };
    const jump_b2_from_b0_inst = try func.dfg.makeInst(jump_b2_from_b0_data);
    try func.layout.appendInst(jump_b2_from_b0_inst, b0);

    // b1
    const const3_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 3 } };
    const const3_inst = try func.dfg.makeInst(const3_data);
    try func.layout.appendInst(const3_inst, b1);
    _ = try func.dfg.appendInstResult(const3_inst, Type.I32);

    const const4_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 4 } };
    const const4_inst = try func.dfg.makeInst(const4_data);
    try func.layout.appendInst(const4_inst, b1);
    _ = try func.dfg.appendInstResult(const4_inst, Type.I32);

    const jump_b2_from_b1_data = InstructionData{ .jump = .{ .opcode = .jump, .destination = b2 } };
    const jump_b2_from_b1_inst = try func.dfg.makeInst(jump_b2_from_b1_data);
    try func.layout.appendInst(jump_b2_from_b1_inst, b1);

    // b2 with two parameters
    var b2_data = try func.dfg.blocks.getOrDefault(b2);

    const v4_index = func.dfg.values.elems.items.len;
    const v4 = Value.new(v4_index);
    const v4_data = try func.dfg.values.getOrDefault(v4);
    v4_data.* = ValueData.param(Type.I32, 0, b2);
    try func.dfg.value_lists.push(&b2_data.params, v4);

    const v5_index = func.dfg.values.elems.items.len;
    const v5 = Value.new(v5_index);
    const v5_data = try func.dfg.values.getOrDefault(v5);
    v5_data.* = ValueData.param(Type.I32, 1, b2);
    try func.dfg.value_lists.push(&b2_data.params, v5);

    // Verify two parameters
    const params = b2_data.getParams(&func.dfg.value_lists);
    try testing.expectEqual(@as(usize, 2), params.len);
    try testing.expect(std.meta.eql(v4, params[0]));
    try testing.expect(std.meta.eql(v5, params[1]));

    // Verify parameter indices
    const v4_def = func.dfg.valueDef(v4).?;
    const v5_def = func.dfg.valueDef(v5).?;
    try testing.expectEqual(@as(usize, 0), v4_def.param.index);
    try testing.expectEqual(@as(usize, 1), v5_def.param.index);
}

// Test: Dominator tree verification

test "SSA: dominator tree verification" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    // Simple linear CFG: b0 -> b1 -> b2
    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b1, b2);

    var domtree = DominatorTree.init(testing.allocator);
    defer domtree.deinit();
    try domtree.compute(testing.allocator, b0, &cfg);

    // Verify dominance properties
    try testing.expect(domtree.dominates(b0, b0));
    try testing.expect(domtree.dominates(b0, b1));
    try testing.expect(domtree.dominates(b0, b2));
    try testing.expect(domtree.dominates(b1, b1));
    try testing.expect(domtree.dominates(b1, b2));
    try testing.expect(domtree.dominates(b2, b2));

    try testing.expect(!domtree.dominates(b1, b0));
    try testing.expect(!domtree.dominates(b2, b0));
    try testing.expect(!domtree.dominates(b2, b1));

    // Verify immediate dominators
    try testing.expect(domtree.idominator(b0) == null); // Entry has no idom
    try testing.expect(std.meta.eql(b0, domtree.idominator(b1).?));
    try testing.expect(std.meta.eql(b1, domtree.idominator(b2).?));

    // Verify dominator tree structure
    try domtree.verify(testing.allocator, b0, &cfg);
}

// Test: Complex CFG dominance

test "SSA: complex CFG with nested diamonds" {
    var cfg = CFG.init(testing.allocator);
    defer cfg.deinit();

    // Nested diamonds:
    //       b0
    //      /  \
    //     b1  b2
    //     |    |
    //     b3  b4
    //      \  /
    //       b5

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);
    const b3 = Block.new(3);
    const b4 = Block.new(4);
    const b5 = Block.new(5);

    try cfg.addEdge(b0, b1);
    try cfg.addEdge(b0, b2);
    try cfg.addEdge(b1, b3);
    try cfg.addEdge(b2, b4);
    try cfg.addEdge(b3, b5);
    try cfg.addEdge(b4, b5);

    var domtree = DominatorTree.init(testing.allocator);
    defer domtree.deinit();
    try domtree.compute(testing.allocator, b0, &cfg);

    // b0 dominates all
    try testing.expect(domtree.dominates(b0, b1));
    try testing.expect(domtree.dominates(b0, b2));
    try testing.expect(domtree.dominates(b0, b3));
    try testing.expect(domtree.dominates(b0, b4));
    try testing.expect(domtree.dominates(b0, b5));

    // b1 dominates only b3
    try testing.expect(domtree.dominates(b1, b3));
    try testing.expect(!domtree.dominates(b1, b4));
    try testing.expect(!domtree.dominates(b1, b5));

    // b2 dominates only b4
    try testing.expect(domtree.dominates(b2, b4));
    try testing.expect(!domtree.dominates(b2, b3));
    try testing.expect(!domtree.dominates(b2, b5));

    // Verify dominance frontiers
    const df_b3 = try domtree.dominanceFrontier(testing.allocator, b3, &cfg);
    defer df_b3.deinit();
    try testing.expectEqual(@as(usize, 1), df_b3.items.len);
    try testing.expect(std.meta.eql(b5, df_b3.items[0]));

    const df_b4 = try domtree.dominanceFrontier(testing.allocator, b4, &cfg);
    defer df_b4.deinit();
    try testing.expectEqual(@as(usize, 1), df_b4.items.len);
    try testing.expect(std.meta.eql(b5, df_b4.items[0]));
}

// Test: Value aliasing for SSA optimization

test "SSA: value aliasing mechanism" {
    const sig = try Signature.init(testing.allocator);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const b0 = try func.dfg.blocks.add();
    try func.layout.appendBlock(b0);

    // Create v0
    const const42_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 42 } };
    const const42_inst = try func.dfg.makeInst(const42_data);
    try func.layout.appendInst(const42_inst, b0);
    const v0 = try func.dfg.appendInstResult(const42_inst, Type.I32);

    // Create v1 as alias to v0
    const v1_index = func.dfg.values.elems.items.len;
    const v1 = Value.new(v1_index);
    const v1_data = try func.dfg.values.getOrDefault(v1);
    v1_data.* = ValueData.alias(Type.I32, v0);

    // Create v2 as alias to v1 (transitive)
    const v2_index = func.dfg.values.elems.items.len;
    const v2 = Value.new(v2_index);
    const v2_data = try func.dfg.values.getOrDefault(v2);
    v2_data.* = ValueData.alias(Type.I32, v1);

    // Resolve aliases - should resolve to v0
    try testing.expect(std.meta.eql(v0, func.dfg.resolveAliases(v1)));
    try testing.expect(std.meta.eql(v0, func.dfg.resolveAliases(v2)));
    try testing.expect(std.meta.eql(v0, func.dfg.resolveAliases(v0)));
}
