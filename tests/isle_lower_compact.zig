const std = @import("std");
const testing = std.testing;
const hoist = @import("hoist");

const isle_impl = hoist.backends.aarch64.isle_impl;
const IsleContext = isle_impl.IsleContext;
const Inst = hoist.backends.aarch64.inst.Inst;
const LowerCtx = hoist.machinst.lower.LowerCtx;
const VCode = hoist.machinst.vcode.VCode;
const Function = hoist.machinst.lower.Function;
const Value = hoist.machinst.lower.Value;
const Type = hoist.types.Type;

test "IsleContext: basic creation" {
    var func = Function.init(testing.allocator);
    defer func.deinit();

    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    const ctx = IsleContext.init(&lower_ctx);
    try testing.expect(@intFromPtr(ctx.lower_ctx) != 0);
}

test "ISLE constructor: aarch64_add_rr emits ADD instruction" {
    var func = Function.init(testing.allocator);
    defer func.deinit();

    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    // Start a block to allow emission
    _ = try lower_ctx.startBlock(hoist.machinst.lower.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);
    const v2 = Value.new(1);

    const dst = try isle_impl.aarch64_add_rr(&ctx, Type.I64, v1, v2);

    // Verify instruction was emitted to VCode
    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.add_rr, @as(std.meta.Tag(Inst), vcode.insns.items[0]));

    // Verify result register
    _ = dst.toReg();
}

test "ISLE constructor: aarch64_madd emits fused multiply-add" {
    var func = Function.init(testing.allocator);
    defer func.deinit();

    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(hoist.machinst.lower.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);
    const v2 = Value.new(1);
    const v3 = Value.new(2);

    // MADD: v3 + (v1 * v2)
    const dst = try isle_impl.aarch64_madd(&ctx, Type.I64, v1, v2, v3);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.madd, @as(std.meta.Tag(Inst), vcode.insns.items[0]));

    _ = dst.toReg();
}

test "ISLE constructor: aarch64_lsl_imm emits logical shift left" {
    var func = Function.init(testing.allocator);
    defer func.deinit();

    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(hoist.machinst.lower.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);

    const dst = try isle_impl.aarch64_lsl_imm(&ctx, Type.I64, v1, 8);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.lsl_imm, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(@as(u8, 8), vcode.insns.items[0].lsl_imm.imm);

    _ = dst.toReg();
}

test "ISLE constructor: multiple instructions build VCode sequence" {
    var func = Function.init(testing.allocator);
    defer func.deinit();

    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(hoist.machinst.lower.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);
    const v2 = Value.new(1);

    // Emit multiple instructions
    _ = try isle_impl.aarch64_add_rr(&ctx, Type.I64, v1, v2);
    _ = try isle_impl.aarch64_mul_rr(&ctx, Type.I64, v1, v2);
    _ = try isle_impl.aarch64_sub_rr(&ctx, Type.I64, v1, v2);

    // All three instructions should be in VCode
    try testing.expectEqual(@as(usize, 3), vcode.insns.items.len);
    try testing.expectEqual(Inst.add_rr, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(Inst.mul_rr, @as(std.meta.Tag(Inst), vcode.insns.items[1]));
    try testing.expectEqual(Inst.sub_rr, @as(std.meta.Tag(Inst), vcode.insns.items[2]));
}
