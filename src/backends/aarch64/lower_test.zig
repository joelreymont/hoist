//! End-to-end lowering integration tests for aarch64.
//!
//! Tests the complete IR -> VCode lowering pipeline.

const std = @import("std");
const testing = std.testing;

const root = @import("../../root.zig");
const lower_mod = root.lower;
const aarch64_lower = @import("../../generated/isle/aarch64_lower_generated.zig");
const isle_impl = root.aarch64_isle_impl;
const inst_mod = @import("inst.zig");
const Inst = inst_mod.Inst;

const Function = root.function.Function;
const Signature = root.signature.Signature;
const AbiParam = root.signature.AbiParam;
const ExternalName = root.extfunc.ExternalName;
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
    // Note: sig ownership transferred to func, func.deinit() frees it
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
    const v0 = try func.dfg.appendInstResult(v0_inst, Type.I64);

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
    // Note: sig ownership transferred to func, func.deinit() frees it
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
    // Note: sig ownership transferred to func, func.deinit() frees it
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

    const sig = Signature.init(testing.allocator, .fast);
    // Note: sig ownership transferred to func, func.deinit() frees it
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

test "lower try_call direct" {
    var sig = Signature.init(testing.allocator, .fast);
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));
    var func = try Function.init(testing.allocator, "test_try_call", sig);
    defer func.deinit();

    var builder = try root.builder.FunctionBuilder.init(testing.allocator, &func);
    defer builder.deinit();

    const block0 = try builder.createBlock();
    const block1 = try builder.createBlock();
    const block2 = try builder.createBlock();
    try builder.appendBlock(block0);
    try builder.appendBlock(block1);
    try builder.appendBlock(block2);

    var callee_sig = Signature.init(testing.allocator, .fast);
    try callee_sig.returns.append(testing.allocator, AbiParam.new(Type.I64));
    const sig_ref = root.entities.SigRef.new(0);
    try func.signatures.set(func.allocator, sig_ref, callee_sig);

    const name = try ExternalName.fromTestcase(testing.allocator, "callee");
    const func_ref = try func.func_metadata.registerExternalFunc(name, sig_ref, .import);

    builder.switchToBlock(block0);
    const call_res = try builder.instTryCall(func_ref, &.{}, block1, block2);
    try builder.sealBlock(block0);

    builder.switchToBlock(block1);
    try builder.retValues(&.{ call_res });
    try builder.sealBlock(block1);

    builder.switchToBlock(block2);
    const zero = try builder.iconst(Type.I64, 0);
    try builder.retValues(&.{ zero });
    try builder.sealBlock(block2);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, testing.allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expectEqual(@as(usize, 3), vcode.blocks.items.len);
}

test "lower try_call indirect" {
    var sig = Signature.init(testing.allocator, .fast);
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));
    var func = try Function.init(testing.allocator, "test_try_call_indirect", sig);
    defer func.deinit();

    var builder = try root.builder.FunctionBuilder.init(testing.allocator, &func);
    defer builder.deinit();

    const block0 = try builder.createBlock();
    const block1 = try builder.createBlock();
    const block2 = try builder.createBlock();
    try builder.appendBlock(block0);
    try builder.appendBlock(block1);
    try builder.appendBlock(block2);

    var callee_sig = Signature.init(testing.allocator, .fast);
    try callee_sig.returns.append(testing.allocator, AbiParam.new(Type.I64));
    const sig_ref = root.entities.SigRef.new(0);
    try func.signatures.set(func.allocator, sig_ref, callee_sig);

    builder.switchToBlock(block0);
    const callee_ptr = try builder.iconst(Type.I64, 0);
    const args_list = try builder.buildValueList(&.{ callee_ptr });

    const inst_data = InstructionData{ .try_call_indirect = .{
        .opcode = .try_call_indirect,
        .sig_ref = sig_ref,
        .args = args_list,
        .normal_successor = block1,
        .exception_successor = block2,
    } };
    const inst = try func.dfg.makeInst(inst_data);
    try func.layout.appendInst(inst, block0);
    const call_res = try func.dfg.appendInstResult(inst, Type.I64);
    try builder.sealBlock(block0);

    builder.switchToBlock(block1);
    try builder.retValues(&.{ call_res });
    try builder.sealBlock(block1);

    builder.switchToBlock(block2);
    const zero = try builder.iconst(Type.I64, 0);
    try builder.retValues(&.{ zero });
    try builder.sealBlock(block2);

    const backend = lower_mod.LowerBackend(Inst){
        .lowerInstFn = lowerInst,
        .lowerBranchFn = lowerBranch,
    };

    var vcode = try lower_mod.lowerFunction(Inst, testing.allocator, &func, backend);
    defer vcode.deinit();

    try testing.expect(vcode.insns.items.len > 0);
    try testing.expectEqual(@as(usize, 3), vcode.blocks.items.len);
}

// Helper wrappers to call generated lowering functions
fn instValue(ctx: *lower_mod.LowerCtx(Inst), inst: lower_mod.Inst) !Value {
    return ctx.func.dfg.firstResult(inst) orelse try ctx.func.dfg.appendInstResult(inst, Type.I8);
}

fn lowerInst(ctx: *lower_mod.LowerCtx(Inst), inst: lower_mod.Inst) !bool {
    var isle_ctx = isle_impl.IsleContext.init(ctx);
    _ = aarch64_lower.lower(&isle_ctx, try instValue(ctx, inst)) catch |err| {
        if (err == error.NoMatch) return false;
        return err;
    };
    return true;
}

fn lowerBranch(ctx: *lower_mod.LowerCtx(Inst), inst: lower_mod.Inst) !bool {
    const inst_data = ctx.getInstData(inst);
    switch (inst_data.*) {
        .branch, .jump, .nullary, .unary => {
            var isle_ctx = isle_impl.IsleContext.init(ctx);
            _ = aarch64_lower.lower(&isle_ctx, try instValue(ctx, inst)) catch |err| {
                if (err == error.NoMatch) return false;
                return err;
            };
            return true;
        },
        else => return false,
    }
}
