const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const CallConv = hoist.signature.CallConv;
const Type = hoist.types.Type;
const ContextBuilder = hoist.context.ContextBuilder;
const OS = hoist.context.OS;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const JitMem = hoist.jit.memory.Mem;

fn buildAddFunction(
    allocator: std.mem.Allocator,
    name: []const u8,
    width: u16,
    call_conv: CallConv,
) !Function {
    var sig = Signature.init(allocator, call_conv);
    errdefer sig.deinit();

    const ty = try intType(width);
    try sig.params.append(allocator, AbiParam.new(ty));
    try sig.params.append(allocator, AbiParam.new(ty));
    try sig.returns.append(allocator, AbiParam.new(ty));

    var func = try Function.init(allocator, name, sig);
    errdefer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);
    try func.dfg.setBlockParams(entry, &.{ ty, ty });

    const param0 = func.dfg.blockParams(entry)[0];
    const param1 = func.dfg.blockParams(entry)[1];

    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ param0, param1 },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_result = try func.dfg.appendInstResult(add_inst, ty);
    try func.layout.appendInst(add_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = add_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    return func;
}

fn aarch64TargetConfig() !struct { os: OS, call_conv: CallConv } {
    return switch (builtin.os.tag) {
        .macos => .{ .os = .macos, .call_conv = .apple_aarch64 },
        .linux => .{ .os = .linux, .call_conv = .system_v },
        else => error.SkipZigTest,
    };
}

fn intType(width: u16) !Type {
    return switch (width) {
        32 => Type.I32,
        64 => Type.I64,
        else => error.UnsupportedType,
    };
}

// Test compilation of a simple function: fn add(a: i32, b: i32) -> i32
test "compile simple add function" {
    const cfg = try aarch64TargetConfig();
    var func = try buildAddFunction(testing.allocator, "test_add", 32, cfg.call_conv);
    defer func.deinit();

    var builder = ContextBuilder.init(testing.allocator);
    var ctx = builder
        .target(.aarch64, cfg.os)
        .optLevel(.none)
        .callConv(cfg.call_conv)
        .verification(true)
        .optimization(false)
        .build();

    var code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test compilation of a function with constants: fn const_test() -> i32 { return 42; }
test "compile constant return" {
    const cfg = try aarch64TargetConfig();
    var sig = Signature.init(testing.allocator, cfg.call_conv);
    errdefer sig.deinit();

    const ret_ty = Type.I32;
    try sig.returns.append(testing.allocator, AbiParam.new(ret_ty));

    var func = try Function.init(testing.allocator, "const_test", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const const_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(42),
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, ret_ty);
    try func.layout.appendInst(const_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(testing.allocator);
    var ctx = builder
        .target(.aarch64, cfg.os)
        .optLevel(.none)
        .build();

    var code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test compilation with optimization enabled
test "compile with optimization" {
    const cfg = try aarch64TargetConfig();
    var sig = Signature.init(testing.allocator, cfg.call_conv);
    errdefer sig.deinit();

    const ty = Type.I32;
    try sig.params.append(testing.allocator, AbiParam.new(ty));
    try sig.returns.append(testing.allocator, AbiParam.new(ty));

    var func = try Function.init(testing.allocator, "opt_test", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);
    try func.dfg.setBlockParams(entry, &.{ty});

    const param0 = func.dfg.blockParams(entry)[0];

    const zero_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(0),
        },
    };
    const zero_inst = try func.dfg.makeInst(zero_data);
    const zero_val = try func.dfg.appendInstResult(zero_inst, ty);
    try func.layout.appendInst(zero_inst, entry);

    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ param0, zero_val },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_result = try func.dfg.appendInstResult(add_inst, ty);
    try func.layout.appendInst(add_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = add_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(testing.allocator);
    var ctx = builder
        .target(.aarch64, cfg.os)
        .optLevel(.basic)
        .optimization(true)
        .build();

    var code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test aarch64 compilation
test "compile for aarch64" {
    const cfg = try aarch64TargetConfig();
    var func = try buildAddFunction(testing.allocator, "test_aarch64", 64, cfg.call_conv);
    defer func.deinit();

    var builder = ContextBuilder.init(testing.allocator);
    var ctx = builder
        .target(.aarch64, cfg.os)
        .optLevel(.none)
        .callConv(cfg.call_conv)
        .build();

    var code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Smoke test: compile and run simple AArch64 add via JIT
// Only runs on AArch64 Linux/macOS hosts.
test "jit smoke: aarch64 add" {
    if (builtin.cpu.arch != .aarch64 and builtin.cpu.arch != .aarch64_be) {
        return error.SkipZigTest;
    }

    const cfg = try aarch64TargetConfig();

    var func = try buildAddFunction(testing.allocator, "jit_add", 64, cfg.call_conv);
    defer func.deinit();

    var builder = ContextBuilder.init(testing.allocator);
    var ctx = builder
        .target(.aarch64, cfg.os)
        .optLevel(.none)
        .callConv(cfg.call_conv)
        .verification(true)
        .optimization(false)
        .build();

    var code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit();

    var mem = try JitMem.init(testing.allocator, code.code.items.len);
    defer mem.deinit();

    const buf = try mem.alloc(code.code.items.len, 16);
    try mem.writeExec(buf, code.code.items);
    try mem.setExec(true);

    const fn_ptr = mem.getFnI64I64ToI64();
    try testing.expectEqual(@as(i64, 42), fn_ptr(40, 2));
}
