//! End-to-end lowering integration tests for aarch64.
//!
//! Tests the complete IR -> VCode lowering pipeline.

const std = @import("std");
const testing = std.testing;

const root = @import("../../root.zig");
const lower_mod = root.lower;
const aarch64_lower = @import("../../generated/aarch64_lower_generated.zig");
const inst_mod = @import("inst.zig");
const Inst = inst_mod.Inst;

const Function = root.function.Function;
const Signature = root.signature.Signature;
const AbiParam = root.signature.AbiParam;
const Type = root.types.Type;
const Block = root.entities.Block;
const Value = root.entities.Value;
const InstructionData = root.instruction_data.InstructionData;

test "lower simple iconst + return" {
    // Build IR: function returning constant 42
    // block0:
    //   v0 = iconst 42
    //   return v0

    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));
    var func = try Function.init(testing.allocator, "test_iconst", sig);
    defer func.deinit();

    // Create entry block
    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    // v0 = iconst 42
    const iconst_data = InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = .{ .value = 42 },
    } };
    const v0_inst = try func.dfg.makeInst(iconst_data);
    try func.layout.appendInst(v0_inst, block0);
    const v0 = func.dfg.firstResult(v0_inst).?;

    // return v0
    const return_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = v0,
    } };
    const ret_inst = try func.dfg.makeInst(return_data);
    try func.layout.appendInst(ret_inst, block0);

    // Lower to VCode
    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, testing.allocator, &func, backend);
    defer vcode.deinit();

    // Verify we got instructions
    try testing.expect(vcode.insns.items.len > 0);

    // Should have 1 block (entry)
    try testing.expectEqual(@as(usize, 1), vcode.blocks.items.len);
}

test "lower iadd + return" {
    // Build IR: function(a: i64, b: i64) -> i64 { return a + b }
    // block0(v0: i64, v1: i64):
    //   v2 = iadd v0, v1
    //   return v2

    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "test_iadd", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    // Block parameters v0, v1
    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);
    const v1 = try func.dfg.appendBlockParam(block0, Type.I64);

    // v2 = iadd v0, v1
    const iadd_data = InstructionData{ .binary = .{
        .opcode = .iadd,
        .args = .{ v0, v1 },
    } };
    const v2_inst = try func.dfg.makeInst(iadd_data);
    try func.layout.appendInst(v2_inst, block0);
    const v2 = func.dfg.firstResult(v2_inst).?;

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

    var vcode = try lower_mod.lowerFunction(Inst, testing.allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expectEqual(@as(usize, 1), vcode.blocks.items.len);

    // Verify block parameters are tracked in VCode
    const vcode_block = vcode.getBlock(0);
    try testing.expectEqual(@as(usize, 2), vcode_block.params.len);
}

test "lower conditional branch" {
    // Build IR: function(cond: i64) { if (cond) goto block1 else goto block2 }
    // block0(v0: i64):
    //   brif v0, block1, block2
    // block1:
    //   return
    // block2:
    //   return
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "test_brif", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    const block1 = try func.dfg.makeBlock();
    const block2 = try func.dfg.makeBlock();

    try func.layout.appendBlock(block0);
    try func.layout.appendBlock(block1);
    try func.layout.appendBlock(block2);

    // block0(v0)
    const v0 = try func.dfg.appendBlockParam(block0, Type.I64);

    // brif v0, block1, block2
    const brif_data = InstructionData{ .branch = .{
        .opcode = .brif,
        .condition = v0,
        .then_dest = block1,
        .else_dest = block2,
    } };
    const brif_inst = try func.dfg.makeInst(brif_data);
    try func.layout.appendInst(brif_inst, block0);

    // block1: return
    const ret1_data = InstructionData{ .nullary = .{ .opcode = .@"return" } };
    const ret1_inst = try func.dfg.makeInst(ret1_data);
    try func.layout.appendInst(ret1_inst, block1);

    // block2: return
    const ret2_data = InstructionData{ .nullary = .{ .opcode = .@"return" } };
    const ret2_inst = try func.dfg.makeInst(ret2_data);
    try func.layout.appendInst(ret2_inst, block2);

    // Lower to VCode
    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, testing.allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expectEqual(@as(usize, 3), vcode.blocks.items.len);
}

test "lower unconditional jump" {
    // Build IR: function { goto block1; } block1 { return }
    // block0:
    //   jump block1
    // block1:
    //   return

    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();
    var func = try Function.init(testing.allocator, "test_jump", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    const block1 = try func.dfg.makeBlock();

    try func.layout.appendBlock(block0);
    try func.layout.appendBlock(block1);

    // jump block1
    const jump_data = InstructionData{ .jump = .{
        .opcode = .jump,
        .destination = block1,
    } };
    const jump_inst = try func.dfg.makeInst(jump_data);
    try func.layout.appendInst(jump_inst, block0);

    // return
    const ret_data = InstructionData{ .nullary = .{ .opcode = .@"return" } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, block1);

    // Lower to VCode
    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, testing.allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expectEqual(@as(usize, 2), vcode.blocks.items.len);
}

// Helper wrappers to call generated lowering functions
fn lowerInst(ctx: *lower_mod.LowerCtx(Inst), inst: lower_mod.Inst) !bool {
    return try aarch64_lower.lower(ctx, inst);
}

fn lowerBranch(ctx: *lower_mod.LowerCtx(Inst), inst: lower_mod.Inst) !bool {
    const inst_data = ctx.getInstData(inst);
    switch (inst_data.*) {
        .branch, .jump, .nullary, .unary => {
            return try aarch64_lower.lower(ctx, inst);
        },
        else => return false,
    }
}
