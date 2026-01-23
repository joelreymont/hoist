//! ISLE rule coverage tests - type conversion operations.
//!
//! Tests IR type conversion operations to verify ISLE lowering rules.
//! Verifies aarch64_sxt*, aarch64_uxt*, aarch64_ireduce, aarch64_fpromote,
//! aarch64_fdemote, aarch64_fcvt*, aarch64_scvtf, aarch64_ucvtf coverage.

const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.function.signature.Signature;
const AbiParam = hoist.function.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;

const aarch64_lower = hoist.aarch64_lower_generated;
const lower_mod = hoist.lower;
const Inst = hoist.aarch64_inst.Inst;
const isle_helpers = hoist.aarch64_isle_helpers;
const isle_coverage = hoist.aarch64_isle_coverage;

test "ISLE coverage: sext i8 to i32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: i8) -> i32 { return (i32)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I8));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_sext_i8_i32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I8);

    // v1 = sext.i32 v0
    const sext_data = InstructionData{ .unary = .{
        .opcode = .sextend,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(sext_data);
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

test "ISLE coverage: bmask i32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: i32) -> i32 { return bmask(x) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_bmask_i32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v1 = bmask.i32 v0
    const bmask_data = InstructionData{ .unary = .{
        .opcode = .bmask,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(bmask_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = try func.dfg.appendInstResult(v1_inst, Type.I32);

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

test "ISLE coverage: bmask i64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: i64) -> i64 { return bmask(x) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_bmask_i64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v1 = bmask.i64 v0
    const bmask_data = InstructionData{ .unary = .{
        .opcode = .bmask,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(bmask_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = try func.dfg.appendInstResult(v1_inst, Type.I64);

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

test "ISLE coverage: sext i16 to i64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: i16) -> i64 { return (i64)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I16));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_sext_i16_i64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I16);

    // v1 = sext.i64 v0
    const sext_data = InstructionData{ .unary = .{
        .opcode = .sextend,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(sext_data);
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

test "ISLE coverage: sext i32 to i64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: i32) -> i64 { return (i64)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_sext_i32_i64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v1 = sext.i64 v0
    const sext_data = InstructionData{ .unary = .{
        .opcode = .sextend,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(sext_data);
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

test "ISLE coverage: uext i8 to i32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: i8) -> i32 { return (u32)(u8)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I8));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_uext_i8_i32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I8);

    // v1 = uext.i32 v0
    const uext_data = InstructionData{ .unary = .{
        .opcode = .uextend,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(uext_data);
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

test "ISLE coverage: uext i16 to i64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: i16) -> i64 { return (u64)(u16)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I16));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_uext_i16_i64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I16);

    // v1 = uext.i64 v0
    const uext_data = InstructionData{ .unary = .{
        .opcode = .uextend,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(uext_data);
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

test "ISLE coverage: ireduce i64 to i32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: i64) -> i32 { return (i32)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_ireduce_i64_i32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v1 = ireduce.i32 v0
    const ireduce_data = InstructionData{ .unary = .{
        .opcode = .ireduce,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(ireduce_data);
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

test "ISLE coverage: ireduce i32 to i16" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: i32) -> i16 { return (i16)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I16));

    var func = try Function.init(allocator, "test_ireduce_i32_i16", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v1 = ireduce.i16 v0
    const ireduce_data = InstructionData{ .unary = .{
        .opcode = .ireduce,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(ireduce_data);
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

test "ISLE coverage: fpromote f32 to f64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: f32) -> f64 { return (f64)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "test_fpromote", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F32);

    // v1 = fpromote.f64 v0
    const fpromote_data = InstructionData{ .unary = .{
        .opcode = .fpromote,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(fpromote_data);
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

test "ISLE coverage: fdemote f64 to f32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: f64) -> f32 { return (f32)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.F32));

    var func = try Function.init(allocator, "test_fdemote", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v1 = fdemote.f32 v0
    const fdemote_data = InstructionData{ .unary = .{
        .opcode = .fdemote,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(fdemote_data);
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

test "ISLE coverage: fcvt_from_sint i32 to f32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: i32) -> f32 { return (f32)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.F32));

    var func = try Function.init(allocator, "test_fcvt_from_sint", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v1 = fcvt_from_sint.f32 v0
    const fcvt_data = InstructionData{ .unary = .{
        .opcode = .fcvt_from_sint,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(fcvt_data);
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

test "ISLE coverage: fcvt_from_uint i64 to f64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: i64) -> f64 { return (f64)(u64)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "test_fcvt_from_uint", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v1 = fcvt_from_uint.f64 v0
    const fcvt_data = InstructionData{ .unary = .{
        .opcode = .fcvt_from_uint,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(fcvt_data);
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

test "ISLE coverage: fcvt_to_sint f32 to i32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: f32) -> i32 { return (i32)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.F32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_fcvt_to_sint", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F32);

    // v1 = fcvt_to_sint.i32 v0
    const fcvt_data = InstructionData{ .unary = .{
        .opcode = .fcvt_to_sint,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(fcvt_data);
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

test "ISLE coverage: fcvt_to_uint f64 to i64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: f64) -> i64 { return (u64)x }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_fcvt_to_uint", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v1 = fcvt_to_uint.i64 v0
    const fcvt_data = InstructionData{ .unary = .{
        .opcode = .fcvt_to_uint,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(fcvt_data);
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

test "ISLE coverage: bitcast i32 to f32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: i32) -> f32 { return bitcast(x) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.F32));

    var func = try Function.init(allocator, "test_bitcast_i32_f32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v1 = bitcast.f32 v0
    const bitcast_data = InstructionData{ .unary = .{
        .opcode = .bitcast,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(bitcast_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = try func.dfg.appendInstResult(v1_inst, Type.F32);

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

test "ISLE coverage: bitcast f64 to i64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(x: f64) -> i64 { return bitcast(x) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.F64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_bitcast_f64_i64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.F64);

    // v1 = bitcast.i64 v0
    const bitcast_data = InstructionData{ .unary = .{
        .opcode = .bitcast,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(bitcast_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = try func.dfg.appendInstResult(v1_inst, Type.I64);

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
