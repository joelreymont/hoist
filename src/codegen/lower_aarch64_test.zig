const std = @import("std");
const testing = std.testing;
const ir = @import("../ir.zig");
const Function = @import("function.zig").Function;
const IRBuilder = @import("irbuilder.zig").IRBuilder;
const compile = @import("compile.zig");
const Inst = @import("../backends/aarch64/inst.zig").Inst;
const VCode = @import("../machinst/vcode.zig").VCode;

test "iconst lowering: small positive immediate" {
    // Create function
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    // Build IR: iconst 42
    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v = try builder.emitIconst(ir.Type.I64, 42);
    _ = v;

    // Lower to machine code
    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = compile.CompileCtx.init(testing.allocator, &func, &vcode, .aarch64);
    defer ctx.deinit();

    try compile.lowerFunction(&ctx);

    // Check that mov_imm was emitted
    try testing.expect(vcode.insts.items.len > 0);
    // Note: Actual instruction checking would require more infrastructure
}

test "iconst lowering: zero" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v = try builder.emitIconst(ir.Type.I64, 0);
    _ = v;

    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = compile.CompileCtx.init(testing.allocator, &func, &vcode, .aarch64);
    defer ctx.deinit();

    try compile.lowerFunction(&ctx);

    try testing.expect(vcode.insts.items.len > 0);
}

test "iconst lowering: negative immediate" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v = try builder.emitIconst(ir.Type.I64, @bitCast(@as(i64, -1)));
    _ = v;

    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = compile.CompileCtx.init(testing.allocator, &func, &vcode, .aarch64);
    defer ctx.deinit();

    try compile.lowerFunction(&ctx);

    try testing.expect(vcode.insts.items.len > 0);
}

test "iconst lowering: large immediate" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    // Large immediate that might need MOVZ+MOVK
    const v = try builder.emitIconst(ir.Type.I64, 0x123456789ABCDEF0);
    _ = v;

    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = compile.CompileCtx.init(testing.allocator, &func, &vcode, .aarch64);
    defer ctx.deinit();

    try compile.lowerFunction(&ctx);

    try testing.expect(vcode.insts.items.len > 0);
}

test "iconst lowering: 32-bit value" {
    const sig = ir.Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    var builder = IRBuilder.init(testing.allocator, &func);
    const block = try builder.createBlock();
    try builder.appendBlock(block);
    builder.switchToBlock(block);

    const v = try builder.emitIconst(ir.Type.I32, 0xDEADBEEF);
    _ = v;

    var vcode = VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = compile.CompileCtx.init(testing.allocator, &func, &vcode, .aarch64);
    defer ctx.deinit();

    try compile.lowerFunction(&ctx);

    try testing.expect(vcode.insts.items.len > 0);
}
