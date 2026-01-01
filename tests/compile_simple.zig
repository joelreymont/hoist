const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Function = root.function.Function;
const Signature = root.signature.Signature;
const Type = root.types.Type;
const Context = root.context.Context;
const ContextBuilder = root.context.ContextBuilder;
const Arch = root.context.Arch;
const OS = root.context.OS;
const OptLevel = root.context.OptLevel;
const InstructionData = root.instruction_data.InstructionData;

/// Test compilation of a simple function: fn add(a: i32, b: i32) -> i32
test "compile simple add function" {
    var sig = try Signature.init(testing.allocator);
    defer sig.deinit(testing.allocator);

    // Add parameters: i32, i32
    try sig.params.append(testing.allocator, Type{ .int = .{ .width = 32 } });
    try sig.params.append(testing.allocator, Type{ .int = .{ .width = 32 } });

    // Return type: i32
    try sig.returns.append(testing.allocator, Type{ .int = .{ .width = 32 } });

    var func = try Function.init(testing.allocator, "test_add", sig);
    defer func.deinit();

    // Create entry block
    const entry = func.dfg.makeBlock() catch unreachable;
    try func.layout.appendBlock(entry);

    // Get parameter values
    const param0 = func.dfg.blockParams(entry)[0];
    const param1 = func.dfg.blockParams(entry)[1];

    // Create iadd instruction: result = param0 + param1
    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ param0, param1 },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_result = try func.dfg.appendInstResult(add_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(add_inst, entry);

    // Create return instruction
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = add_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Build context for x64
    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .optLevel(.none)
        .callConv(.system_v)
        .verify(true)
        .optimize(false)
        .build();

    // Compile (should not crash)
    const code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit(testing.allocator);

    // Verify we got some code
    try testing.expect(code.buffer.len > 0);
}

/// Test compilation of a function with constants: fn const_test() -> i32 { return 42; }
test "compile constant return" {
    var sig = try Signature.init(testing.allocator);
    defer sig.deinit(testing.allocator);

    // Return type: i32
    try sig.returns.append(testing.allocator, Type{ .int = .{ .width = 32 } });

    var func = try Function.init(testing.allocator, "const_test", sig);
    defer func.deinit();

    const entry = func.dfg.makeBlock() catch unreachable;
    try func.layout.appendBlock(entry);

    // Create iconst instruction: result = 42
    const const_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 42,
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(const_inst, entry);

    // Return constant
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .optLevel(.none)
        .build();

    const code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit(testing.allocator);

    try testing.expect(code.buffer.len > 0);
}

/// Test compilation with optimization enabled
test "compile with optimization" {
    var sig = try Signature.init(testing.allocator);
    defer sig.deinit(testing.allocator);

    try sig.params.append(testing.allocator, Type{ .int = .{ .width = 32 } });
    try sig.returns.append(testing.allocator, Type{ .int = .{ .width = 32 } });

    var func = try Function.init(testing.allocator, "opt_test", sig);
    defer func.deinit();

    const entry = func.dfg.makeBlock() catch unreachable;
    try func.layout.appendBlock(entry);

    const param0 = func.dfg.blockParams(entry)[0];

    // x + 0 should be optimized away
    const zero_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 0,
        },
    };
    const zero_inst = try func.dfg.makeInst(zero_data);
    const zero_val = try func.dfg.appendInstResult(zero_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(zero_inst, entry);

    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ param0, zero_val },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_result = try func.dfg.appendInstResult(add_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(add_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = add_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .optLevel(.speed)
        .optimize(true)
        .build();

    const code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit(testing.allocator);

    try testing.expect(code.buffer.len > 0);
}

/// Test aarch64 compilation
test "compile for aarch64" {
    var sig = try Signature.init(testing.allocator);
    defer sig.deinit(testing.allocator);

    try sig.params.append(testing.allocator, Type{ .int = .{ .width = 64 } });
    try sig.params.append(testing.allocator, Type{ .int = .{ .width = 64 } });
    try sig.returns.append(testing.allocator, Type{ .int = .{ .width = 64 } });

    var func = try Function.init(testing.allocator, "test_aarch64", sig);
    defer func.deinit();

    const entry = func.dfg.makeBlock() catch unreachable;
    try func.layout.appendBlock(entry);

    const param0 = func.dfg.blockParams(entry)[0];
    const param1 = func.dfg.blockParams(entry)[1];

    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ param0, param1 },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_result = try func.dfg.appendInstResult(add_inst, Type{ .int = .{ .width = 64 } });
    try func.layout.appendInst(add_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = add_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.aarch64, .linux)
        .optLevel(.none)
        .callConv(.aapcs64)
        .build();

    const code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit(testing.allocator);

    try testing.expect(code.buffer.len > 0);
}
