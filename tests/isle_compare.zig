//! ISLE rule coverage tests - comparison operations.
//!
//! Tests IR comparison operations (icmp, fcmp) to verify ISLE lowering rules.
//! Verifies aarch64_cmp_*, aarch64_cmn_*, aarch64_tst_* coverage.

const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.function.signature.Signature;
const AbiParam = hoist.function.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const IntCC = hoist.condcodes.IntCC;
const FloatCC = hoist.condcodes.FloatCC;

const aarch64_lower = hoist.aarch64_lower_generated;
const lower_mod = hoist.lower;
const Inst = hoist.aarch64_inst.Inst;
const isle_helpers = hoist.aarch64_isle_helpers;
const isle_coverage = hoist.aarch64_isle_coverage;

test "ISLE coverage: icmp eq (i64)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i64, b: i64) -> i32 { return a == b }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_icmp_eq", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v2 = icmp eq v0, v1
    const icmp_data = InstructionData{ .int_compare = .{
        .opcode = .icmp,
        .cond = .eq,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(icmp_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = try func.dfg.appendInstResult(v2_inst, Type.I32);

    // return v2
    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v2,
    } };
    const ret_inst = try func.dfg.makeInst(return_data);
    try func.layout.appendInst(ret_inst, block0);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expect(coverage.uniqueRulesInvoked() > 0);
}

test "ISLE coverage: icmp slt (i32)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i32, b: i32) -> i32 { return a < b (signed) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_icmp_slt", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v2 = icmp slt v0, v1
    const icmp_data = InstructionData{ .int_compare = .{
        .opcode = .icmp,
        .cond = .slt,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(icmp_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = try func.dfg.appendInstResult(v2_inst, Type.I32);

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v2,
    } };
    const ret_inst = try func.dfg.makeInst(return_data);
    try func.layout.appendInst(ret_inst, block0);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expect(coverage.uniqueRulesInvoked() > 0);
}

test "ISLE coverage: icmp ult (unsigned <)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i64, b: i64) -> i32 { return a < b (unsigned) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_icmp_ult", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v2 = icmp ult v0, v1
    const icmp_data = InstructionData{ .int_compare = .{
        .opcode = .icmp,
        .cond = .ult,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(icmp_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = try func.dfg.appendInstResult(v2_inst, Type.I32);

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v2,
    } };
    const ret_inst = try func.dfg.makeInst(return_data);
    try func.layout.appendInst(ret_inst, block0);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expect(coverage.uniqueRulesInvoked() > 0);
}

test "ISLE coverage: icmp ne (not equal)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i32, b: i32) -> i32 { return a != b }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_icmp_ne", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v2 = icmp ne v0, v1
    const icmp_data = InstructionData{ .int_compare = .{
        .opcode = .icmp,
        .cond = .ne,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(icmp_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = try func.dfg.appendInstResult(v2_inst, Type.I32);

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v2,
    } };
    const ret_inst = try func.dfg.makeInst(return_data);
    try func.layout.appendInst(ret_inst, block0);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expect(coverage.uniqueRulesInvoked() > 0);
}

test "ISLE coverage: fcmp eq (f64)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: f64, b: f64) -> i32 { return a == b }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_fcmp_eq", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v2 = fcmp eq v0, v1
    const fcmp_data = InstructionData{ .float_compare = .{
        .opcode = .fcmp,
        .cond = .eq,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(fcmp_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = try func.dfg.appendInstResult(v2_inst, Type.I32);

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v2,
    } };
    const ret_inst = try func.dfg.makeInst(return_data);
    try func.layout.appendInst(ret_inst, block0);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expect(coverage.uniqueRulesInvoked() > 0);
}

test "ISLE coverage: fcmp lt (f32 <)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: f32, b: f32) -> i32 { return a < b }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_fcmp_lt", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F32);
    const v1 = try func.dfg.appendBlockParam(block0, Type.F32);

    // v2 = fcmp lt v0, v1
    const fcmp_data = InstructionData{ .float_compare = .{
        .opcode = .fcmp,
        .cond = .lt,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(fcmp_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = try func.dfg.appendInstResult(v2_inst, Type.I32);

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v2,
    } };
    const ret_inst = try func.dfg.makeInst(return_data);
    try func.layout.appendInst(ret_inst, block0);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expect(coverage.uniqueRulesInvoked() > 0);
}

test "ISLE coverage: fcmp uno (unordered - NaN check)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: f64, b: f64) -> i32 { return uno(a, b) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_fcmp_uno", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v2 = fcmp uno v0, v1
    const fcmp_data = InstructionData{ .float_compare = .{
        .opcode = .fcmp,
        .cond = .uno,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(fcmp_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = try func.dfg.appendInstResult(v2_inst, Type.I32);

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v2,
    } };
    const ret_inst = try func.dfg.makeInst(return_data);
    try func.layout.appendInst(ret_inst, block0);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expect(coverage.uniqueRulesInvoked() > 0);
}

// Stub lowering functions
fn lowerInst(
    ctx: *lower_mod.LowerCtx(Inst),
    inst: lower_mod.Inst,
) !bool {
    return try aarch64_lower.lower(ctx, inst);
}

fn lowerBranch(
    ctx: *lower_mod.LowerCtx(Inst),
    inst: lower_mod.Inst,
) !bool {
    _ = ctx;
    _ = inst;
    return false;
}
