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
const Opcode = hoist.opcodes.Opcode;
const MemFlags = hoist.memflags.MemFlags;

const aarch64_backend = hoist.aarch64_lower;
const lower_mod = hoist.lower;
const Inst = hoist.aarch64_inst.Inst;
const isle_helpers = hoist.aarch64_isle_helpers;
const isle_coverage = hoist.aarch64_isle_coverage;

test "ISLE coverage: load i64" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(ptr: i64) -> i64 { return *ptr }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
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
        .flags = MemFlags.default(),
        .arg = v0,
        .offset = 0,
    } };
    const v1_inst = try func.dfg.makeInst(load_data);
    try func.layout.appendInst(v1_inst, block0);
    _ = try func.dfg.appendInstResult(v1_inst, Type.I64);
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
    // Note: sig ownership transfers to func, func.deinit() frees it
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
        .flags = MemFlags.default(),
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

test "ISLE coverage: istore8 lowers to STRB constructor" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    var sig = Signature.init(allocator, .fast);
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_istore8", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const ptr = try func.dfg.appendBlockParam(block0, Type.I64);
    const val = try func.dfg.appendBlockParam(block0, Type.I32);

    const store_data = InstructionData{ .store = .{
        .opcode = .istore8,
        .flags = MemFlags.default(),
        .args = .{ val, ptr },
        .offset = 0,
    } };
    const store_inst = try func.dfg.makeInst(store_data);
    try func.layout.appendInst(store_inst, block0);

    const ret_inst = try func.dfg.makeInst(.{ .nullary = .{ .opcode = .@"return" } });
    try func.layout.appendInst(ret_inst, block0);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };
    var vcode = try lower_mod.lowerFunction(Inst, allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expect(coverage.getCount("aarch64_istore8") > 0);
}

test "ISLE coverage: istore16 lowers to STRH constructor" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    var sig = Signature.init(allocator, .fast);
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_istore16", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const ptr = try func.dfg.appendBlockParam(block0, Type.I64);
    const val = try func.dfg.appendBlockParam(block0, Type.I32);

    const store_data = InstructionData{ .store = .{
        .opcode = .istore16,
        .flags = MemFlags.default(),
        .args = .{ val, ptr },
        .offset = 0,
    } };
    const store_inst = try func.dfg.makeInst(store_data);
    try func.layout.appendInst(store_inst, block0);

    const ret_inst = try func.dfg.makeInst(.{ .nullary = .{ .opcode = .@"return" } });
    try func.layout.appendInst(ret_inst, block0);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };
    var vcode = try lower_mod.lowerFunction(Inst, allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expect(coverage.getCount("aarch64_istore16") > 0);
}

test "ISLE coverage: istore32 lowers to STR size32 constructor" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    var sig = Signature.init(allocator, .fast);
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_istore32", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const ptr = try func.dfg.appendBlockParam(block0, Type.I64);
    const val = try func.dfg.appendBlockParam(block0, Type.I32);

    const store_data = InstructionData{ .store = .{
        .opcode = .istore32,
        .flags = MemFlags.default(),
        .args = .{ val, ptr },
        .offset = 0,
    } };
    const store_inst = try func.dfg.makeInst(store_data);
    try func.layout.appendInst(store_inst, block0);

    const ret_inst = try func.dfg.makeInst(.{ .nullary = .{ .opcode = .@"return" } });
    try func.layout.appendInst(ret_inst, block0);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };
    var vcode = try lower_mod.lowerFunction(Inst, allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expect(coverage.getCount("aarch64_istore32") > 0);
}

test "ISLE coverage: sload8 (sign-extend i8)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(ptr: i64) -> i64 { return (i64)*((i8*)ptr) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
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
        .flags = MemFlags.default(),
        .arg = v0,
        .offset = 0,
    } };
    const v1_inst = try func.dfg.makeInst(load_data);
    try func.layout.appendInst(v1_inst, block0);
    _ = try func.dfg.appendInstResult(v1_inst, Type.I64);
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
    try testing.expect(coverage.getCount("aarch64_sload8") > 0);
}

test "ISLE coverage: uload16 (zero-extend i16)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(ptr: i64) -> i32 { return (i32)*((u16*)ptr) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
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
        .flags = MemFlags.default(),
        .arg = v0,
        .offset = 0,
    } };
    const v1_inst = try func.dfg.makeInst(load_data);
    try func.layout.appendInst(v1_inst, block0);
    _ = try func.dfg.appendInstResult(v1_inst, Type.I32);
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
    try testing.expect(coverage.getCount("aarch64_uload16") > 0);
}

test "ISLE coverage: sload32 (sign-extend i32 to i64)" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(ptr: i64) -> i64 { return (i64)*((i32*)ptr) }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
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
        .flags = MemFlags.default(),
        .arg = v0,
        .offset = 0,
    } };
    const v1_inst = try func.dfg.makeInst(load_data);
    try func.layout.appendInst(v1_inst, block0);
    _ = try func.dfg.appendInstResult(v1_inst, Type.I64);
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
    try testing.expect(coverage.getCount("aarch64_sload32") > 0);
}

test "ISLE coverage: load with offset" {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    // Build IR: fn(ptr: i64) -> i64 { return ptr[16] }
    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it
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
        .flags = MemFlags.default(),
        .arg = v0,
        .offset = 128,
    } };
    const v1_inst = try func.dfg.makeInst(load_data);
    try func.layout.appendInst(v1_inst, block0);
    _ = try func.dfg.appendInstResult(v1_inst, Type.I64);
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

test "ISLE coverage: uload8x8 widening load" {
    try expectWidenLoadRule(.uload8x8, Type.I16X8, "aarch64_uload8x8");
}

test "ISLE coverage: sload8x8 widening load" {
    try expectWidenLoadRule(.sload8x8, Type.I16X8, "aarch64_sload8x8");
}

test "ISLE coverage: uload16x4 widening load" {
    try expectWidenLoadRule(.uload16x4, Type.I32X4, "aarch64_uload16x4");
}

test "ISLE coverage: sload16x4 widening load" {
    try expectWidenLoadRule(.sload16x4, Type.I32X4, "aarch64_sload16x4");
}

test "ISLE coverage: uload32x2 widening load" {
    try expectWidenLoadRule(.uload32x2, Type.I64X2, "aarch64_uload32x2");
}

test "ISLE coverage: sload32x2 widening load" {
    try expectWidenLoadRule(.sload32x2, Type.I64X2, "aarch64_sload32x2");
}

fn expectWidenLoadRule(opcode: Opcode, ret_ty: Type, rule_name: []const u8) !void {
    const allocator = testing.allocator;

    var coverage = isle_coverage.IsleRuleCoverage.init(allocator);
    defer coverage.deinit();
    isle_helpers.setIsleCoverageTracker(&coverage);
    defer isle_helpers.setIsleCoverageTracker(null);

    var sig = Signature.init(allocator, .fast);
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(ret_ty));

    var func = try Function.init(allocator, "test_widen_load", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const ptr = try func.dfg.appendBlockParam(block0, Type.I64);
    const load_data = InstructionData{ .load = .{
        .opcode = opcode,
        .flags = MemFlags.default(),
        .arg = ptr,
        .offset = 0,
    } };
    const load_inst = try func.dfg.makeInst(load_data);
    try func.layout.appendInst(load_inst, block0);
    _ = try func.dfg.appendInstResult(load_inst, ret_ty);
    const load_val = func.dfg.firstResult(load_inst).?;

    const ret_inst = try func.dfg.makeInst(.{ .unary = .{
        .opcode = .@"return",
        .arg = load_val,
    } });
    try func.layout.appendInst(ret_inst, block0);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };
    var vcode = try lower_mod.lowerFunction(Inst, allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expect(coverage.getCount(rule_name) > 0);
}

// Stub lowering functions
fn lowerInst(
    ctx: *lower_mod.LowerCtx(Inst),
    inst: lower_mod.Inst,
) !bool {
    return try aarch64_backend.Aarch64Lower.lowerInst(ctx, inst);
}

fn lowerBranch(
    ctx: *lower_mod.LowerCtx(Inst),
    inst: lower_mod.Inst,
) !bool {
    return try aarch64_backend.Aarch64Lower.lowerBranch(ctx, inst);
}
