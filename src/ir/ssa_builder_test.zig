const std = @import("std");
const testing = std.testing;

const root = @import("../root.zig");
const ir = @import("../ir.zig");
const Function = ir.Function;
const Signature = root.signature.Signature;
const SSABuilder = ir.SSABuilder;
const Variable = ir.Variable;
const Type = root.types.Type;
const CFG = @import("cfg.zig").ControlFlowGraph;

// SSA Builder Tests - verify use_var/def_var/seal semantics

test "SSABuilder: single block" {
    const sig = Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var ssa = try SSABuilder.init(testing.allocator);
    defer ssa.deinit();

    const b0 = try func.dfg.addBlock();
    try func.layout.appendBlock(b0);

    // x = 42
    const c42 = try func.dfg.makeConst(42);
    const x = @as(Variable, @enumFromInt(0));
    try ssa.defVar(x, c42, b0);

    // y = use x
    const y = try ssa.useVar(&func, x, Type.I64, b0);
    try testing.expectEqual(c42, y);
}

test "SSABuilder: linear chain" {
    const sig = Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var ssa = try SSABuilder.init(testing.allocator);
    defer ssa.deinit();

    const b0 = try func.dfg.addBlock();
    const b1 = try func.dfg.addBlock();
    try func.layout.appendBlock(b0);
    try func.layout.appendBlock(b1);

    // Build CFG
    func.cfg = try CFG.init(testing.allocator, &func);

    const x = @as(Variable, @enumFromInt(0));

    // b0: x = 42; jump b1
    const c42 = try func.dfg.makeConst(42);
    try ssa.defVar(x, c42, b0);

    const jmp = try func.dfg.makeInst(.{ .jump = .{ .opcode = .jump, .destination = b1 } });
    try func.layout.appendInst(jmp, b0);

    try ssa.sealBlock(&func, b0);
    try ssa.sealBlock(&func, b1);

    // b1: y = use x (should get 42 from b0)
    const y = try ssa.useVar(&func, x, Type.I64, b1);
    try testing.expectEqual(c42, y);
}

test "SSABuilder: phi insertion" {
    const sig = Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var ssa = try SSABuilder.init(testing.allocator);
    defer ssa.deinit();

    const b0 = try func.dfg.addBlock();
    const b1 = try func.dfg.addBlock();
    const b2 = try func.dfg.addBlock();
    const b3 = try func.dfg.addBlock();

    try func.layout.appendBlock(b0);
    try func.layout.appendBlock(b1);
    try func.layout.appendBlock(b2);
    try func.layout.appendBlock(b3);

    func.cfg = try CFG.init(testing.allocator, &func);

    const x = @as(Variable, @enumFromInt(0));

    // b0: x = 1; br b3
    const c1 = try func.dfg.makeConst(1);
    try ssa.defVar(x, c1, b0);
    const j0 = try func.dfg.makeInst(.{ .jump = .{ .opcode = .jump, .destination = b3 } });
    try func.layout.appendInst(j0, b0);
    try ssa.sealBlock(&func, b0);

    // b1: x = 2; br b3
    const c2 = try func.dfg.makeConst(2);
    try ssa.defVar(x, c2, b1);
    const j1 = try func.dfg.makeInst(.{ .jump = .{ .opcode = .jump, .destination = b3 } });
    try func.layout.appendInst(j1, b1);
    try ssa.sealBlock(&func, b1);

    // b2: x = 3; br b3
    const c3 = try func.dfg.makeConst(3);
    try ssa.defVar(x, c3, b2);
    const j2 = try func.dfg.makeInst(.{ .jump = .{ .opcode = .jump, .destination = b3 } });
    try func.layout.appendInst(j2, b2);
    try ssa.sealBlock(&func, b2);

    // Rebuild CFG to pick up edges
    func.cfg.?.deinit();
    func.cfg = try CFG.init(testing.allocator, &func);

    // b3: y = use x (should create phi)
    try ssa.sealBlock(&func, b3);
    const y = try ssa.useVar(&func, x, Type.I64, b3);

    // y should be a block param (phi node)
    const def = func.dfg.valueDef(y).?;
    try testing.expectEqual(b3, def.param.?.block);
}

test "SSABuilder: redundant phi removal" {
    const sig = Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var ssa = try SSABuilder.init(testing.allocator);
    defer ssa.deinit();

    const b0 = try func.dfg.addBlock();
    const b1 = try func.dfg.addBlock();
    const b2 = try func.dfg.addBlock();

    try func.layout.appendBlock(b0);
    try func.layout.appendBlock(b1);
    try func.layout.appendBlock(b2);

    func.cfg = try CFG.init(testing.allocator, &func);

    const x = @as(Variable, @enumFromInt(0));

    // b0: x = 42; br b2
    const c42 = try func.dfg.makeConst(42);
    try ssa.defVar(x, c42, b0);
    const j0 = try func.dfg.makeInst(.{ .jump = .{ .opcode = .jump, .destination = b2 } });
    try func.layout.appendInst(j0, b0);
    try ssa.sealBlock(&func, b0);

    // b1: x = 42; br b2 (same value!)
    try ssa.defVar(x, c42, b1);
    const j1 = try func.dfg.makeInst(.{ .jump = .{ .opcode = .jump, .destination = b2 } });
    try func.layout.appendInst(j1, b1);
    try ssa.sealBlock(&func, b1);

    // Rebuild CFG
    func.cfg.?.deinit();
    func.cfg = try CFG.init(testing.allocator, &func);

    // b2: y = use x (should optimize away redundant phi)
    try ssa.sealBlock(&func, b2);
    const y = try ssa.useVar(&func, x, Type.I64, b2);

    // y should be c42, not a phi
    const canonical = func.dfg.resolveAliases(y);
    try testing.expectEqual(c42, canonical);
}
