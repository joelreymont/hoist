//! ISLE rule coverage tests - bitwise and shift operations.
//!
//! Tests IR bitwise/shift operations to verify ISLE lowering rules.
//! Verifies aarch64_and_*, aarch64_orr_*, aarch64_eor_*, aarch64_lsl_*,
//! aarch64_lsr_*, aarch64_asr_*, aarch64_clz_*, aarch64_ctz_*, aarch64_bswap_* coverage.

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

test "ISLE coverage: band (bitwise AND)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i64, b: i64) -> i64 { return a & b }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_band", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v2 = band v0, v1
    const band_data = InstructionData{ .binary = .{
        .opcode = .band,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(band_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = func.dfg.firstResult(v2_inst).?;

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

test "ISLE coverage: bor (bitwise OR)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i32, b: i32) -> i32 { return a | b }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_bor", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v2 = bor v0, v1
    const bor_data = InstructionData{ .binary = .{
        .opcode = .bor,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(bor_data);
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

test "ISLE coverage: bxor (bitwise XOR)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i64, b: i64) -> i64 { return a ^ b }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_bxor", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v2 = bxor v0, v1
    const bxor_data = InstructionData{ .binary = .{
        .opcode = .bxor,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(bxor_data);
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

test "ISLE coverage: ishl (logical left shift)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i32, shift: i32) -> i32 { return a << shift }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_ishl", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v2 = ishl v0, v1
    const ishl_data = InstructionData{ .binary = .{
        .opcode = .ishl,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(ishl_data);
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

test "ISLE coverage: ushr (unsigned right shift)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i64, shift: i64) -> i64 { return a >> shift (unsigned) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_ushr", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v2 = ushr v0, v1
    const ushr_data = InstructionData{ .binary = .{
        .opcode = .ushr,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(ushr_data);
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

test "ISLE coverage: sshr (signed right shift)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i32, shift: i32) -> i32 { return a >> shift (signed) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_sshr", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v2 = sshr v0, v1
    const sshr_data = InstructionData{ .binary = .{
        .opcode = .sshr,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(sshr_data);
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

test "ISLE coverage: rotl (rotate left)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i64, shift: i64) -> i64 { return rotl(a, shift) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_rotl", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v2 = rotl v0, v1
    const rotl_data = InstructionData{ .binary = .{
        .opcode = .rotl,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(rotl_data);
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

test "ISLE coverage: clz (count leading zeros)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i64) -> i64 { return clz(a) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_clz", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v1 = clz v0
    const clz_data = InstructionData{ .unary = .{
        .opcode = .clz,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(clz_data);
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

test "ISLE coverage: ctz (count trailing zeros)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i32) -> i32 { return ctz(a) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_ctz", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v1 = ctz v0
    const ctz_data = InstructionData{ .unary = .{
        .opcode = .ctz,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(ctz_data);
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

test "ISLE coverage: bswap (byte swap)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i64) -> i64 { return bswap(a) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_bswap", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v1 = bswap v0
    const bswap_data = InstructionData{ .unary = .{
        .opcode = .bswap,
        .arg = v0,
    } };
    const v1_inst = try func.dfg.makeInst(bswap_data);
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
