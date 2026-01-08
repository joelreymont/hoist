//! ISLE rule coverage tests - floating-point arithmetic operations.
//!
//! Tests IR float operations to verify ISLE lowering rules.
//! Verifies aarch64_fadd, aarch64_fsub, aarch64_fmul, aarch64_fdiv,
//! aarch64_fmin, aarch64_fmax, aarch64_ceil, aarch64_floor,
//! aarch64_nearest, aarch64_fcopysign_* coverage.

const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.function.signature.Signature;
const AbiParam = hoist.function.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;

const aarch64_lower = @import("../src/generated/aarch64_lower_generated.zig");
const lower_mod = hoist.lower;
const Inst = hoist.aarch64_inst.Inst;
const isle_helpers = @import("../src/backends/aarch64/isle_helpers.zig");
const isle_coverage = @import("../src/backends/aarch64/isle_coverage.zig");

test "ISLE coverage: fadd f32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: f32, b: f32) -> f32 { return a + b }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.returns.append(allocator, AbiParam.new(Type.F32));

    var func = try Function.init(allocator, "test_fadd_f32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F32);
    const v1 = try func.dfg.appendBlockParam(block0, Type.F32);

    // v2 = fadd v0, v1
    const fadd_data = InstructionData{ .binary = .{
        .opcode = .fadd,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(fadd_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = func.dfg.firstResult(v2_inst).?;

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

test "ISLE coverage: fadd f64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: f64, b: f64) -> f64 { return a + b }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "test_fadd_f64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v2 = fadd v0, v1
    const fadd_data = InstructionData{ .binary = .{
        .opcode = .fadd,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(fadd_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = func.dfg.firstResult(v2_inst).?;

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

test "ISLE coverage: fsub f64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: f64, b: f64) -> f64 { return a - b }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "test_fsub_f64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v2 = fsub v0, v1
    const fsub_data = InstructionData{ .binary = .{
        .opcode = .fsub,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(fsub_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = func.dfg.firstResult(v2_inst).?;

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

test "ISLE coverage: fmul f32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: f32, b: f32) -> f32 { return a * b }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.returns.append(allocator, AbiParam.new(Type.F32));

    var func = try Function.init(allocator, "test_fmul_f32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F32);
    const v1 = try func.dfg.appendBlockParam(block0, Type.F32);

    // v2 = fmul v0, v1
    const fmul_data = InstructionData{ .binary = .{
        .opcode = .fmul,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(fmul_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = func.dfg.firstResult(v2_inst).?;

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

test "ISLE coverage: fdiv f64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: f64, b: f64) -> f64 { return a / b }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "test_fdiv_f64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v2 = fdiv v0, v1
    const fdiv_data = InstructionData{ .binary = .{
        .opcode = .fdiv,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(fdiv_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = func.dfg.firstResult(v2_inst).?;

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

test "ISLE coverage: fmin f64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: f64, b: f64) -> f64 { return min(a, b) }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "test_fmin_f64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v2 = fmin v0, v1
    const fmin_data = InstructionData{ .binary = .{
        .opcode = .fmin,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(fmin_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = func.dfg.firstResult(v2_inst).?;

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

test "ISLE coverage: fmax f32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: f32, b: f32) -> f32 { return max(a, b) }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.returns.append(allocator, AbiParam.new(Type.F32));

    var func = try Function.init(allocator, "test_fmax_f32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F32);
    const v1 = try func.dfg.appendBlockParam(block0, Type.F32);

    // v2 = fmax v0, v1
    const fmax_data = InstructionData{ .binary = .{
        .opcode = .fmax,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(fmax_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = func.dfg.firstResult(v2_inst).?;

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

test "ISLE coverage: ceil f64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: f64) -> f64 { return ceil(x) }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "test_ceil_f64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v1 = ceil v0
    const ceil_data = InstructionData{ .unary = .{
        .opcode = .ceil,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(ceil_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = func.dfg.firstResult(v1_inst).?;

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v1,
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

test "ISLE coverage: floor f32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: f32) -> f32 { return floor(x) }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.returns.append(allocator, AbiParam.new(Type.F32));

    var func = try Function.init(allocator, "test_floor_f32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F32);

    // v1 = floor v0
    const floor_data = InstructionData{ .unary = .{
        .opcode = .floor,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(floor_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = func.dfg.firstResult(v1_inst).?;

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v1,
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

test "ISLE coverage: trunc f64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: f64) -> f64 { return trunc(x) }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "test_trunc_f64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v1 = trunc v0
    const trunc_data = InstructionData{ .unary = .{
        .opcode = .trunc,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(trunc_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = func.dfg.firstResult(v1_inst).?;

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v1,
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

test "ISLE coverage: nearest f32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: f32) -> f32 { return round_to_nearest_even(x) }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.returns.append(allocator, AbiParam.new(Type.F32));

    var func = try Function.init(allocator, "test_nearest_f32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F32);

    // v1 = nearest v0
    const nearest_data = InstructionData{ .unary = .{
        .opcode = .nearest,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(nearest_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = func.dfg.firstResult(v1_inst).?;

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v1,
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

test "ISLE coverage: copysign f64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(mag: f64, sign: f64) -> f64 { return copysign(mag, sign) }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "test_copysign_f64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v2 = copysign v0, v1
    const copysign_data = InstructionData{ .binary = .{
        .opcode = .copysign,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(copysign_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = func.dfg.firstResult(v2_inst).?;

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

test "ISLE coverage: fabs f32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: f32) -> f32 { return fabs(x) }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.returns.append(allocator, AbiParam.new(Type.F32));

    var func = try Function.init(allocator, "test_fabs_f32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F32);

    // v1 = fabs v0
    const fabs_data = InstructionData{ .unary = .{
        .opcode = .fabs,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(fabs_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = func.dfg.firstResult(v1_inst).?;

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v1,
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

test "ISLE coverage: fneg f64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: f64) -> f64 { return -x }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "test_fneg_f64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v1 = fneg v0
    const fneg_data = InstructionData{ .unary = .{
        .opcode = .fneg,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(fneg_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = func.dfg.firstResult(v1_inst).?;

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v1,
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

test "ISLE coverage: sqrt f64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: f64) -> f64 { return sqrt(x) }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "test_sqrt_f64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v1 = sqrt v0
    const sqrt_data = InstructionData{ .unary = .{
        .opcode = .sqrt,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(sqrt_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = func.dfg.firstResult(v1_inst).?;

    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v1,
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
