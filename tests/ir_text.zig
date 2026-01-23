const std = @import("std");
const testing = std.testing;
const ohsnap = @import("ohsnap");

const Parser = @import("../src/ir/text/parser.zig").Parser;
const Printer = @import("../src/ir/text/printer.zig").Printer;
const FunctionBuilder = @import("../src/ir/builder.zig").FunctionBuilder;
const Function = @import("../src/ir/function.zig").Function;
const Type = @import("../src/ir/types.zig").Type;
const IntCC = @import("../src/ir/condcodes.zig").IntCC;
const Signature = @import("../src/ir/signature.zig").Signature;
const AbiParam = @import("../src/ir/signature.zig").AbiParam;

test "parse simple add" {
    const src =
        \\function "add"(i32, i32) -> i32 {
        \\block0(v0: i32, v1: i32):
        \\  v2 = iadd v0, v1
        \\  jump block0(v2)
        \\}
    ;

    const alloc = testing.allocator;
    var p = try Parser.init(alloc, src);
    defer p.deinit();

    var func = try p.parseFunction();
    defer func.deinit();

    try testing.expectEqualStrings("add", func.name);
    try testing.expectEqual(@as(usize, 2), func.signature.params.items.len);
    try testing.expectEqual(@as(usize, 1), func.signature.returns.items.len);
}

test "parse branch" {
    const src =
        \\function "fib"(i32) -> i32 {
        \\block0(v0: i32):
        \\  v1 = iconst 1
        \\  v2 = icmp sle v0, v1
        \\  brif v2, block1, block2
        \\block1:
        \\  jump block1(v0)
        \\block2:
        \\  jump block2(v1)
        \\}
    ;

    const alloc = testing.allocator;
    var p = try Parser.init(alloc, src);
    defer p.deinit();

    var func = try p.parseFunction();
    defer func.deinit();

    try testing.expectEqualStrings("fib", func.name);
}

test "round-trip simple add" {
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

    var p = try Parser.init(alloc, txt);
    defer p.deinit();

    var parsed = try p.parseFunction();
    defer parsed.deinit();

    try testing.expectEqualStrings(func.name, parsed.name);
    try testing.expectEqual(func.signature.params.items.len, parsed.signature.params.items.len);
    try testing.expectEqual(func.signature.returns.items.len, parsed.signature.returns.items.len);
}

test "round-trip branch" {
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

    var p = try Parser.init(alloc, txt);
    defer p.deinit();

    var parsed = try p.parseFunction();
    defer parsed.deinit();

    try testing.expectEqualStrings(func.name, parsed.name);
}

test "error - invalid type" {
    const src =
        \\function "bad"(foo) -> i32 {
        \\block0:
        \\  v0 = iconst 0
        \\  jump block0(v0)
        \\}
    ;

    const alloc = testing.allocator;
    var p = try Parser.init(alloc, src);
    defer p.deinit();

    const res = p.parseFunction();
    try testing.expectError(error.InvalidType, res);
}

test "error - invalid opcode" {
    const src =
        \\function "bad"() -> i32 {
        \\block0:
        \\  v0 = notanop 42
        \\  jump block0(v0)
        \\}
    ;

    const alloc = testing.allocator;
    var p = try Parser.init(alloc, src);
    defer p.deinit();

    const res = p.parseFunction();
    try testing.expectError(error.InvalidOpcode, res);
}

test "error - unexpected eof" {
    const src =
        \\function "incomplete"() -> i32 {
        \\block0:
    ;

    const alloc = testing.allocator;
    var p = try Parser.init(alloc, src);
    defer p.deinit();

    const res = p.parseFunction();
    try testing.expectError(error.UnexpectedEof, res);
}
