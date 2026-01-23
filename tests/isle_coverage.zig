//! ISLE rule coverage tests - arithmetic operations.
//!
//! Tests IR arithmetic operations to verify ISLE lowering rules work correctly.
//! Uses coverage tracking to ensure all arithmetic ISLE rules are exercised.

const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.function.signature.Signature;
const AbiParam = hoist.function.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const Opcode = hoist.opcodes.Opcode;

const aarch64_lower = hoist.aarch64_lower_generated;
const lower_mod = hoist.lower;
const Inst = hoist.aarch64_inst.Inst;
const isle_helpers = hoist.aarch64_isle_helpers;
const isle_coverage = hoist.aarch64_isle_coverage;

test "ISLE coverage: iadd i64 register + register" {
    const allocator = testing.allocator;

    // Enable coverage tracking
    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i64, b: i64) -> i64 { return a + b }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_iadd_i64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    // Block parameters: v0 (a), v1 (b)
    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v2 = iadd v0, v1
    const iadd_data = InstructionData{ .binary = .{
        .opcode = .iadd,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(iadd_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = try func.dfg.appendInstResult(v2_inst, Type.I64);

    // return v2
    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v2,
    } };
    const ret_inst = try func.dfg.makeInst(return_data);
    try func.layout.appendInst(ret_inst, block0);

    // Lower to VCode
    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, allocator, &func, backend);
    defer vcode.deinit();

    // Verify lowering succeeded
    try testing.expect(vcode.insns.items.len > 0);

    // Check coverage - should have invoked an ADD-related rule
    try testing.expect(coverage.uniqueRulesInvoked() > 0);

    // Print coverage report for debugging
    var buf = std.ArrayList(u8){};
    defer buf.deinit(allocator);
    try coverage.report(buf.writer(allocator));
    std.debug.print("\n{s}\n", .{buf.items});
}

test "ISLE coverage: iadd i32 register + immediate" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i32) -> i32 { return a + 42 }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_iadd_imm", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v1 = iconst 42
    const iconst_data = InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = .{ .value = 42 },
    } };
    const v1_inst = try func.dfg.makeInst(iconst_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = try func.dfg.appendInstResult(v1_inst, Type.I32);

    // v2 = iadd v0, v1
    const iadd_data = InstructionData{ .binary = .{
        .opcode = .iadd,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(iadd_data);
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

test "ISLE coverage: isub i64 register - register" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i64, b: i64) -> i64 { return a - b }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_isub_i64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v2 = isub v0, v1
    const isub_data = InstructionData{ .binary = .{
        .opcode = .isub,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(isub_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = try func.dfg.appendInstResult(v2_inst, Type.I64);

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

test "ISLE coverage: imul i32 register * register" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(a: i32, b: i32) -> i32 { return a * b }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_imul_i32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I32);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I32);

    // v2 = imul v0, v1
    const imul_data = InstructionData{ .binary = .{
        .opcode = .imul,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(imul_data);
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

// Stub lowering functions (required by lowerFunction)
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
