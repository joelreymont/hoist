const std = @import("std");
const testing = std.testing;

const Printer = @import("printer.zig").Printer;
const FunctionBuilder = @import("../builder.zig").FunctionBuilder;
const Function = @import("../function.zig").Function;
const Type = @import("../types.zig").Type;
const IntCC = @import("../condcodes.zig").IntCC;
const Signature = @import("../signature.zig").Signature;
const AbiParam = @import("../signature.zig").AbiParam;
const CallConv = @import("../signature.zig").CallConv;

test "printer - simple add" {
    const alloc = testing.allocator;

    var sig = Signature.init(alloc, .fast);
    defer sig.deinit();
    try sig.params.append(alloc, AbiParam.new(Type.I32));
    try sig.params.append(alloc, AbiParam.new(Type.I32));
    try sig.returns.append(alloc, AbiParam.new(Type.I32));

    var func = try Function.init(alloc, "add", sig);
    defer func.deinit();

    var fb = try FunctionBuilder.init(testing.allocator, &func);
    const blk = try fb.createBlock();
    fb.switchToBlock(blk);

    const v0 = try fb.appendBlockParam(blk, Type.I32);
    const v1 = try fb.appendBlockParam(blk, Type.I32);
    const v2 = try fb.iadd(Type.I32, v0, v1);
    try fb.jumpArgs(blk, &.{v2});

    var pr = Printer.init(alloc, &func);
    defer pr.deinit();

    try pr.print();
    const txt = pr.finish();

    try testing.expect(std.mem.indexOf(u8, txt, "function \"add\"") != null);
    try testing.expect(std.mem.indexOf(u8, txt, "iadd") != null);
}

test "printer - branch" {
    const alloc = testing.allocator;

    var sig = Signature.init(alloc, .fast);
    defer sig.deinit();
    try sig.params.append(alloc, AbiParam.new(Type.I32));
    try sig.returns.append(alloc, AbiParam.new(Type.I32));

    var func = try Function.init(alloc, "fib", sig);
    defer func.deinit();

    var fb = try FunctionBuilder.init(testing.allocator, &func);
    const b0 = try fb.createBlock();
    const b1 = try fb.createBlock();
    const b2 = try fb.createBlock();

    fb.switchToBlock(b0);
    const v0 = try fb.appendBlockParam(b0, Type.I32);
    const v1 = try fb.iconst(Type.I32, 1);
    const v2 = try fb.icmp(Type.I32, IntCC.sle, v0, v1);
    try fb.brif(v2, b1, b2);

    fb.switchToBlock(b1);
    try fb.jumpArgs(b1, &.{v0});

    fb.switchToBlock(b2);
    try fb.jumpArgs(b2, &.{v1});

    var pr = Printer.init(alloc, &func);
    defer pr.deinit();

    try pr.print();
    const txt = pr.finish();

    try testing.expect(std.mem.indexOf(u8, txt, "brif") != null);
    try testing.expect(std.mem.indexOf(u8, txt, "icmp sle") != null);
}
