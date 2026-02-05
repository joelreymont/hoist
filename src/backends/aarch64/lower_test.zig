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
const vcode_mod = @import("../../machinst/vcode.zig");
const Inst = inst_mod.Inst;

const Function = root.function.Function;
const Signature = root.signature.Signature;
const AbiParam = root.signature.AbiParam;
const ExternalName = root.extfunc.ExternalName;
const Type = root.types.Type;
const Imm128 = root.immediates.Imm128;
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
    try builder.retValues(&.{call_res});
    try builder.sealBlock(block1);

    builder.switchToBlock(block2);
    const zero = try builder.iconst(Type.I64, 0);
    try builder.retValues(&.{zero});
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
    const args_list = try builder.buildValueList(&.{callee_ptr});

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
    try builder.retValues(&.{call_res});
    try builder.sealBlock(block1);

    builder.switchToBlock(block2);
    const zero = try builder.iconst(Type.I64, 0);
    try builder.retValues(&.{zero});
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

test "lower istore8 emits strb" {
    var vcode = try lowerStoreVCode(.istore8, Type.I32);
    defer vcode.deinit();
    try expectStoreInst(&vcode, .strb);
}

test "lower istore16 emits strh" {
    var vcode = try lowerStoreVCode(.istore16, Type.I16);
    defer vcode.deinit();
    try expectStoreInst(&vcode, .strh);
}

test "lower istore32 emits str" {
    var vcode = try lowerStoreVCode(.istore32, Type.I32);
    defer vcode.deinit();
    try expectStoreInst(&vcode, .str32);
}

test "lower shuffle dup8 emits vec_dup_lane" {
    const mask = [_]u8{3} ** 16;
    var vcode = try lowerShuffleVCode(mask);
    defer vcode.deinit();
    try expectShuffleInst(&vcode, .dup_lane);
}

test "lower shuffle ext emits vec_ext" {
    const mask = maskExt(4);
    var vcode = try lowerShuffleVCode(mask);
    defer vcode.deinit();
    try expectShuffleInst(&vcode, .ext);
}

test "lower shuffle uzp1 emits uzp1" {
    const mask = maskBytesFromU128(0x1e1c_1a18_1614_1210_0e0c_0a08_0604_0200);
    var vcode = try lowerShuffleVCode(mask);
    defer vcode.deinit();
    try expectShuffleInst(&vcode, .uzp1);
}

test "lower shuffle zip1 emits zip1" {
    const mask = maskBytesFromU128(0x1707_1606_1505_1404_1303_1202_1101_1000);
    var vcode = try lowerShuffleVCode(mask);
    defer vcode.deinit();
    try expectShuffleInst(&vcode, .zip1);
}

test "lower shuffle trn1 emits trn1" {
    const mask = maskBytesFromU128(0x1e0e_1c0c_1a0a_1808_1606_1404_1202_1000);
    var vcode = try lowerShuffleVCode(mask);
    defer vcode.deinit();
    try expectShuffleInst(&vcode, .trn1);
}

test "lower shuffle rev16 emits vec_rev16" {
    const mask = maskBytesFromU128(0x0e0f_0c0d_0a0b_0809_0607_0405_0203_0001);
    var vcode = try lowerShuffleVCode(mask);
    defer vcode.deinit();
    try expectShuffleInst(&vcode, .rev16);
}

test "lower shuffle fallback emits table lookup" {
    const mask = [_]u8{ 0, 5, 10, 15, 16, 21, 26, 31, 3, 8, 13, 18, 23, 28, 1, 6 };
    var vcode = try lowerShuffleVCode(mask);
    defer vcode.deinit();
    try expectShuffleInst(&vcode, .tbl);
}

test "lower signed dotprod pattern emits vec_sdot when enabled" {
    var vcode = try lowerDotprodPatternVCode(true, true);
    defer vcode.deinit();
    try expectDotprodInst(&vcode, .sdot, true);
}

test "lower unsigned dotprod pattern emits vec_udot when enabled" {
    var vcode = try lowerDotprodPatternVCode(false, true);
    defer vcode.deinit();
    try expectDotprodInst(&vcode, .udot, true);
}

// Helper wrappers to call generated lowering functions
fn instValue(ctx: *lower_mod.LowerCtx(Inst), inst: lower_mod.Inst) !Value {
    return ctx.func.dfg.firstResult(inst) orelse try ctx.func.dfg.appendInstResult(inst, Type.I8);
}

const StoreKind = enum { strb, strh, str32 };
const ShuffleKind = enum { dup_lane, ext, uzp1, zip1, trn1, rev16, tbl };
const DotprodKind = enum { sdot, udot };

fn lowerStoreVCode(opcode: root.opcodes.Opcode, val_ty: Type) !vcode_mod.VCode(Inst) {
    const allocator = testing.allocator;

    var sig = Signature.init(allocator, .fast);
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(val_ty));

    var func = try Function.init(allocator, "test_store_lowering", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const ptr = try func.dfg.appendBlockParam(block0, Type.I64);
    const val = try func.dfg.appendBlockParam(block0, val_ty);

    const store_data = InstructionData{ .store = .{
        .opcode = opcode,
        .flags = root.memflags.MemFlags.default(),
        .args = .{ ptr, val },
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

    return try lower_mod.lowerFunction(Inst, allocator, &func, backend);
}

fn lowerShuffleVCode(mask_bytes: [16]u8) !vcode_mod.VCode(Inst) {
    const allocator = testing.allocator;

    var sig = Signature.init(allocator, .fast);
    try sig.params.append(allocator, AbiParam.new(Type.I8X16));
    try sig.params.append(allocator, AbiParam.new(Type.I8X16));

    var func = try Function.init(allocator, "test_shuffle_lowering", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const a = try func.dfg.appendBlockParam(block0, Type.I8X16);
    const b = try func.dfg.appendBlockParam(block0, Type.I8X16);

    const shuffle_data = InstructionData{ .shuffle = .{
        .opcode = .shuffle,
        .args = .{ a, b },
        .mask = Imm128.new(mask_bytes),
    } };
    const shuffle_inst = try func.dfg.makeInst(shuffle_data);
    try func.layout.appendInst(shuffle_inst, block0);
    _ = try func.dfg.appendInstResult(shuffle_inst, Type.I8X16);

    var vcode = vcode_mod.VCode(Inst).init(allocator);
    errdefer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(allocator, &func, &vcode);
    defer ctx.deinit();
    try ctx.allocateSSAVRegs();
    _ = try ctx.startBlock(block0);
    defer ctx.endBlock();

    const handled = try lowerInst(&ctx, shuffle_inst);
    try testing.expect(handled);
    return vcode;
}

fn lowerDotprodPatternVCode(is_signed: bool, enable_dotprod: bool) !vcode_mod.VCode(Inst) {
    const allocator = testing.allocator;

    var sig = Signature.init(allocator, .fast);
    try sig.params.append(allocator, AbiParam.new(Type.I32X4));
    try sig.params.append(allocator, AbiParam.new(Type.I8X16));
    try sig.params.append(allocator, AbiParam.new(Type.I8X16));
    try sig.returns.append(allocator, AbiParam.new(Type.I32X4));

    var func = try Function.init(allocator, "test_dotprod_lowering", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const acc = try func.dfg.appendBlockParam(block0, Type.I32X4);
    const x = try func.dfg.appendBlockParam(block0, Type.I8X16);
    const y = try func.dfg.appendBlockParam(block0, Type.I8X16);

    const widen_low_op: root.opcodes.Opcode = if (is_signed) .swiden_low else .uwiden_low;
    const widen_high_op: root.opcodes.Opcode = if (is_signed) .swiden_high else .uwiden_high;

    const x_low_inst = try func.dfg.makeInst(.{ .unary = .{
        .opcode = widen_low_op,
        .arg = x,
    } });
    try func.layout.appendInst(x_low_inst, block0);
    const x_low = try func.dfg.appendInstResult(x_low_inst, Type.I16X8);

    const y_low_inst = try func.dfg.makeInst(.{ .unary = .{
        .opcode = widen_low_op,
        .arg = y,
    } });
    try func.layout.appendInst(y_low_inst, block0);
    const y_low = try func.dfg.appendInstResult(y_low_inst, Type.I16X8);

    const mul_low_inst = try func.dfg.makeInst(.{ .binary = .{
        .opcode = .imul,
        .args = .{ x_low, y_low },
    } });
    try func.layout.appendInst(mul_low_inst, block0);
    const mul_low = try func.dfg.appendInstResult(mul_low_inst, Type.I16X8);

    const pair_low_inst = try func.dfg.makeInst(.{ .unary = .{
        .opcode = .iadd_pairwise,
        .arg = mul_low,
    } });
    try func.layout.appendInst(pair_low_inst, block0);
    const pair_low = try func.dfg.appendInstResult(pair_low_inst, Type.I32X4);

    const x_high_inst = try func.dfg.makeInst(.{ .unary = .{
        .opcode = widen_high_op,
        .arg = x,
    } });
    try func.layout.appendInst(x_high_inst, block0);
    const x_high = try func.dfg.appendInstResult(x_high_inst, Type.I16X8);

    const y_high_inst = try func.dfg.makeInst(.{ .unary = .{
        .opcode = widen_high_op,
        .arg = y,
    } });
    try func.layout.appendInst(y_high_inst, block0);
    const y_high = try func.dfg.appendInstResult(y_high_inst, Type.I16X8);

    const mul_high_inst = try func.dfg.makeInst(.{ .binary = .{
        .opcode = .imul,
        .args = .{ x_high, y_high },
    } });
    try func.layout.appendInst(mul_high_inst, block0);
    const mul_high = try func.dfg.appendInstResult(mul_high_inst, Type.I16X8);

    const pair_high_inst = try func.dfg.makeInst(.{ .unary = .{
        .opcode = .iadd_pairwise,
        .arg = mul_high,
    } });
    try func.layout.appendInst(pair_high_inst, block0);
    const pair_high = try func.dfg.appendInstResult(pair_high_inst, Type.I32X4);

    const pair_sum_inst = try func.dfg.makeInst(.{ .binary = .{
        .opcode = .iadd,
        .args = .{ pair_low, pair_high },
    } });
    try func.layout.appendInst(pair_sum_inst, block0);
    const pair_sum = try func.dfg.appendInstResult(pair_sum_inst, Type.I32X4);

    const final_inst = try func.dfg.makeInst(.{ .binary = .{
        .opcode = .iadd,
        .args = .{ acc, pair_sum },
    } });
    try func.layout.appendInst(final_inst, block0);
    const result = try func.dfg.appendInstResult(final_inst, Type.I32X4);

    var features = root.target.AArch64Features.baseline();
    if (enable_dotprod) {
        features.enable(root.target.AArch64Features.DOTPROD);
    }

    var vcode = vcode_mod.VCode(Inst).init(allocator);
    errdefer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(allocator, &func, &vcode);
    defer ctx.deinit();
    ctx.setFeatures(features);
    try ctx.allocateSSAVRegs();
    _ = try ctx.startBlock(block0);
    defer ctx.endBlock();

    const handled = try lowerInst(&ctx, final_inst);
    try testing.expect(handled);
    _ = result;

    return vcode;
}

fn expectStoreInst(vcode: *const vcode_mod.VCode(Inst), kind: StoreKind) !void {
    var found = false;
    for (vcode.insns.items) |inst| {
        switch (inst) {
            .strb => if (kind == .strb) {
                found = true;
                break;
            },
            .strh => if (kind == .strh) {
                found = true;
                break;
            },
            .str => |s| if (kind == .str32 and s.size == .size32) {
                found = true;
                break;
            },
            else => {},
        }
    }
    try testing.expect(found);
}

fn expectShuffleInst(vcode: *const vcode_mod.VCode(Inst), kind: ShuffleKind) !void {
    var found = false;
    for (vcode.insns.items) |inst| {
        switch (inst) {
            .vec_dup_lane => if (kind == .dup_lane) {
                found = true;
                break;
            },
            .vec_ext => if (kind == .ext) {
                found = true;
                break;
            },
            .uzp1 => if (kind == .uzp1) {
                found = true;
                break;
            },
            .zip1 => if (kind == .zip1) {
                found = true;
                break;
            },
            .trn1 => if (kind == .trn1) {
                found = true;
                break;
            },
            .vec_rev16 => if (kind == .rev16) {
                found = true;
                break;
            },
            .tbl, .vec_tbl2 => if (kind == .tbl) {
                found = true;
                break;
            },
            else => {},
        }
    }
    try testing.expect(found);
}

fn expectDotprodInst(vcode: *const vcode_mod.VCode(Inst), kind: DotprodKind, expected: bool) !void {
    var found = false;
    for (vcode.insns.items) |inst| {
        switch (inst) {
            .vec_sdot => if (kind == .sdot) {
                found = true;
                break;
            },
            .vec_udot => if (kind == .udot) {
                found = true;
                break;
            },
            else => {},
        }
    }
    try testing.expectEqual(expected, found);
}

fn maskBytesFromU128(mask: u128) [16]u8 {
    var bytes: [16]u8 = undefined;
    var i: usize = 0;
    while (i < 16) : (i += 1) {
        const shift: u7 = @intCast(i * 8);
        bytes[i] = @truncate(mask >> shift);
    }
    return bytes;
}

fn maskExt(start: u8) [16]u8 {
    var bytes: [16]u8 = undefined;
    var i: usize = 0;
    while (i < 16) : (i += 1) {
        bytes[i] = @truncate(@as(u16, start) + @as(u16, @intCast(i)));
    }
    return bytes;
}

fn lowerInst(ctx: *lower_mod.LowerCtx(Inst), inst: lower_mod.Inst) !bool {
    var isle_ctx = isle_impl.IsleContext.init(ctx);
    const lowered = aarch64_lower.lower(&isle_ctx, try instValue(ctx, inst)) catch |err| {
        if (err == error.NoMatch) return false;
        return err;
    };
    try ctx.emit(lowered);
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
