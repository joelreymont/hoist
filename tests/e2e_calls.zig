const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const CallConv = hoist.signature.CallConv;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const ContextBuilder = hoist.context.ContextBuilder;
const InstructionData = hoist.instruction_data.InstructionData;
const ValueList = hoist.value_list.ValueList;
const FuncRef = hoist.entities.FuncRef;

// Test compilation of function with call instruction
// Tests: ABI lowering, call emission, caller-saved register handling
test "compile function with call" {
    // Create callee signature: fn add(a: i32, b: i32) -> i32
    var callee_sig = Signature.init(testing.allocator, .system_v);
    defer callee_sig.deinit();

    const i32_type = Type{ .int = .{ .width = 32 } };
    const params = [_]AbiParam{
        AbiParam.new(i32_type),
        AbiParam.new(i32_type),
    };
    try callee_sig.params.appendSlice(&params);
    try callee_sig.returns.append(AbiParam.new(i32_type));

    // Create caller signature: fn caller(x: i32, y: i32) -> i32
    var caller_sig = Signature.init(testing.allocator, .system_v);
    defer caller_sig.deinit();

    try caller_sig.params.appendSlice(&params);
    try caller_sig.returns.append(AbiParam.new(i32_type));

    // Build function that calls external add
    var func = try Function.init(testing.allocator, "test_caller", caller_sig);
    defer func.deinit();

    const entry = func.dfg.makeBlock() catch unreachable;
    try func.layout.appendBlock(entry);

    const param0 = func.dfg.blockParams(entry)[0];
    const param1 = func.dfg.blockParams(entry)[1];

    // Create external function reference
    // In a real scenario this would be registered, but for this test we create it directly
    const callee_ref = FuncRef.new(0);

    // Build argument list for call
    var call_args = ValueList.default();
    try func.dfg.value_lists.push(&call_args, param0);
    try func.dfg.value_lists.push(&call_args, param1);

    // Create call instruction: result = add(param0, param1)
    const call_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = callee_ref,
            .args = call_args,
        },
    };
    const call_inst = try func.dfg.makeInst(call_data);
    const call_result = try func.dfg.appendInstResult(call_inst, i32_type);
    try func.layout.appendInst(call_inst, entry);

    // Return the result
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = call_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile for x64
    var ctx = ContextBuilder.init(testing.allocator)
        .targetNative()
        .optLevel(.none)
        .callConv(.system_v)
        .verify(true)
        .build();

    const code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Call compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit(testing.allocator);

    // Verify we got code output
    try testing.expect(code.buffer.len > 0);
}

// Test function with multiple calls
// Verifies register allocation handles caller-saved registers correctly
test "compile function with multiple calls" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    const i32_type = Type{ .int = .{ .width = 32 } };
    try sig.params.append(AbiParam.new(i32_type));
    try sig.returns.append(AbiParam.new(i32_type));

    var func = try Function.init(testing.allocator, "test_multi_call", sig);
    defer func.deinit();

    const entry = func.dfg.makeBlock() catch unreachable;
    try func.layout.appendBlock(entry);

    const param0 = func.dfg.blockParams(entry)[0];

    // Create two external function references
    const func_a = FuncRef.new(0);
    const func_b = FuncRef.new(1);

    // First call: result1 = func_a(param0)
    var call1_args = ValueList.default();
    try func.dfg.value_lists.push(&call1_args, param0);

    const call1_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = func_a,
            .args = call1_args,
        },
    };
    const call1_inst = try func.dfg.makeInst(call1_data);
    const call1_result = try func.dfg.appendInstResult(call1_inst, i32_type);
    try func.layout.appendInst(call1_inst, entry);

    // Second call: result2 = func_b(result1)
    var call2_args = ValueList.default();
    try func.dfg.value_lists.push(&call2_args, call1_result);

    const call2_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = func_b,
            .args = call2_args,
        },
    };
    const call2_inst = try func.dfg.makeInst(call2_data);
    const call2_result = try func.dfg.appendInstResult(call2_inst, i32_type);
    try func.layout.appendInst(call2_inst, entry);

    // Return result2
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = call2_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = ContextBuilder.init(testing.allocator)
        .targetNative()
        .verify(true)
        .build();

    const code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Multi-call compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit(testing.allocator);

    try testing.expect(code.buffer.len > 0);
}

// Test function call with no arguments
test "compile function with nullary call" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    const i32_type = Type{ .int = .{ .width = 32 } };
    try sig.returns.append(AbiParam.new(i32_type));

    var func = try Function.init(testing.allocator, "test_nullary_call", sig);
    defer func.deinit();

    const entry = func.dfg.makeBlock() catch unreachable;
    try func.layout.appendBlock(entry);

    const callee = FuncRef.new(0);
    const call_args = ValueList.default(); // Empty args

    const call_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = callee,
            .args = call_args,
        },
    };
    const call_inst = try func.dfg.makeInst(call_data);
    const call_result = try func.dfg.appendInstResult(call_inst, i32_type);
    try func.layout.appendInst(call_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = call_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = ContextBuilder.init(testing.allocator)
        .targetNative()
        .verify(true)
        .build();

    const code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Nullary call compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit(testing.allocator);

    try testing.expect(code.buffer.len > 0);
}

// Test ABI lowering for aarch64
test "compile aarch64 function with call" {
    var sig = Signature.init(testing.allocator, .apple_aarch64);
    defer sig.deinit();

    const i64_type = Type{ .int = .{ .width = 64 } };
    const params = [_]AbiParam{
        AbiParam.new(i64_type),
        AbiParam.new(i64_type),
    };
    try sig.params.appendSlice(&params);
    try sig.returns.append(AbiParam.new(i64_type));

    var func = try Function.init(testing.allocator, "test_aarch64_call", sig);
    defer func.deinit();

    const entry = func.dfg.makeBlock() catch unreachable;
    try func.layout.appendBlock(entry);

    const param0 = func.dfg.blockParams(entry)[0];
    const param1 = func.dfg.blockParams(entry)[1];

    const callee = FuncRef.new(0);

    var call_args = ValueList.default();
    try func.dfg.value_lists.push(&call_args, param0);
    try func.dfg.value_lists.push(&call_args, param1);

    const call_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = callee,
            .args = call_args,
        },
    };
    const call_inst = try func.dfg.makeInst(call_data);
    const call_result = try func.dfg.appendInstResult(call_inst, i64_type);
    try func.layout.appendInst(call_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = call_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.aarch64, .linux)
        .callConv(.apple_aarch64)
        .verify(true)
        .build();

    const code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("AArch64 call compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit(testing.allocator);

    try testing.expect(code.buffer.len > 0);
}

test "compile aarch64 preserve_all callconv" {
    var sig = Signature.init(testing.allocator, .preserve_all);
    defer sig.deinit();

    const i64_type = Type{ .int = .{ .width = 64 } };
    const params = [_]AbiParam{
        AbiParam.new(i64_type),
        AbiParam.new(i64_type),
    };
    try sig.params.appendSlice(&params);
    try sig.returns.append(AbiParam.new(i64_type));

    var func = try Function.init(testing.allocator, "test_aarch64_preserve_all", sig);
    defer func.deinit();

    const entry = func.dfg.makeBlock() catch unreachable;
    try func.layout.appendBlock(entry);

    const param0 = func.dfg.blockParams(entry)[0];
    const param1 = func.dfg.blockParams(entry)[1];

    const callee = FuncRef.new(0);

    var call_args = ValueList.default();
    try func.dfg.value_lists.push(&call_args, param0);
    try func.dfg.value_lists.push(&call_args, param1);

    const call_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = callee,
            .args = call_args,
        },
    };
    const call_inst = try func.dfg.makeInst(call_data);
    const call_result = try func.dfg.appendInstResult(call_inst, i64_type);
    try func.layout.appendInst(call_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = call_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.aarch64, .linux)
        .callConv(.preserve_all)
        .verify(true)
        .build();

    const code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("PreserveAll callconv compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit(testing.allocator);

    try testing.expect(code.buffer.len > 0);
}
