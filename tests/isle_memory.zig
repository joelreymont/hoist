//! ISLE rule coverage tests - memory operations.
//!
//! Tests IR load/store operations to verify ISLE lowering rules.
//! Verifies aarch64_ldr_*, aarch64_str_*, aarch64_sload*, aarch64_uload* coverage.

const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.function.signature.Signature;
const AbiParam = hoist.function.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const MemFlags = hoist.memflags.MemFlags;

const aarch64_lower = @import("../src/generated/aarch64_lower_generated.zig");
const lower_mod = hoist.lower;
const Inst = hoist.aarch64_inst.Inst;
const isle_helpers = @import("../src/backends/aarch64/isle_helpers.zig");
const isle_coverage = @import("../src/backends/aarch64/isle_coverage.zig");

test "ISLE coverage: load i64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(ptr: i64) -> i64 { return *ptr }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_load_i64", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v1 = load v0+0
    const load_data = InstructionData{ .load = .{
        .opcode = .load,
        .flags = MemFlags.new(),
        .arg = v0,
        .offset = 0,
    } };
    const v1_inst = try func.dfg.makeInst(load_data);
    try func.layout.appendInst(v1_inst, block0);
    const v1 = func.dfg.firstResult(v1_inst).?;

    // return v1
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

test "ISLE coverage: store i32" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(ptr: i64, val: i32) { *ptr = val }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_store_i32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I32);

    // store v1, v0+0
    const store_data = InstructionData{ .store = .{
        .opcode = .store,
        .flags = MemFlags.new(),
        .args = .{ v1, v0 },
        .offset = 0,
    } };
    const store_inst = try func.dfg.makeInst(store_data);
    try func.layout.appendInst(store_inst, block0);

    // return
    const return_data = InstructionData{ .nullary = .{
        .opcode = .@"return",
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

test "ISLE coverage: sload8 (sign-extend i8)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(ptr: i64) -> i64 { return (i64)*((i8*)ptr) }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_sload8", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v1 = sload8 v0+0
    const load_data = InstructionData{ .load = .{
        .opcode = .sload8,
        .flags = MemFlags.new(),
        .arg = v0,
        .offset = 0,
    } };
    const v1_inst = try func.dfg.makeInst(load_data);
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

test "ISLE coverage: uload16 (zero-extend i16)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(ptr: i64) -> i32 { return (i32)*((u16*)ptr) }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_uload16", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v1 = uload16 v0+0
    const load_data = InstructionData{ .load = .{
        .opcode = .uload16,
        .flags = MemFlags.new(),
        .arg = v0,
        .offset = 0,
    } };
    const v1_inst = try func.dfg.makeInst(load_data);
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

test "ISLE coverage: sload32 (sign-extend i32 to i64)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(ptr: i64) -> i64 { return (i64)*((i32*)ptr) }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_sload32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v1 = sload32 v0+0
    const load_data = InstructionData{ .load = .{
        .opcode = .sload32,
        .flags = MemFlags.new(),
        .arg = v0,
        .offset = 0,
    } };
    const v1_inst = try func.dfg.makeInst(load_data);
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

test "ISLE coverage: load with offset" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(ptr: i64) -> i64 { return ptr[16] }
    var sig = Signature.init(allocator, .fast);
    defer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_load_offset", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v1 = load v0+128 (16 * 8 bytes)
    const load_data = InstructionData{ .load = .{
        .opcode = .load,
        .flags = MemFlags.new(),
        .arg = v0,
        .offset = 128,
    } };
    const v1_inst = try func.dfg.makeInst(load_data);
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
