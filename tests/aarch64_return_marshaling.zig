const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const ContextBuilder = hoist.context.ContextBuilder;
const ExternalName = hoist.entities.ExternalName;

// Test single integer return (X0)
test "Return marshaling: single i32 in X0" {
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    // fn() -> i32
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "test_single_i32_ret", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Constant 42
    const const42_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(42),
        },
    };
    const const42_inst = try func.dfg.makeInst(const42_data);
    const const42_result = try func.dfg.appendInstResult(const42_inst, Type.I32);
    try func.layout.appendInst(const42_inst, entry);

    // Return
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const42_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile
    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Verify code was generated
    try testing.expect(code.code.items.len > 0);
}

// Test single f64 return (V0)
test "Return marshaling: single f64 in V0" {
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    // fn() -> f64
    try sig.returns.append(testing.allocator, AbiParam.new(Type.F64));

    var func = try Function.init(testing.allocator, "test_single_f64_ret", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // FP constant 3.14
    const const_data = InstructionData{
        .unary_imm = .{
            .opcode = .f64const,
            .imm = Imm64.fromF64(3.14),
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, Type.F64);
    try func.layout.appendInst(const_inst, entry);

    // Return
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile
    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Verify code was generated
    try testing.expect(code.code.items.len > 0);
}

// Test i128 return (X0 + X1)
test "Return marshaling: i128 in X0+X1" {
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    // fn() -> i128
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I128));

    var func = try Function.init(testing.allocator, "test_i128_ret", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Constant (large i128 value)
    const const_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(0x123456789ABCDEF0),
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, Type.I128);
    try func.layout.appendInst(const_inst, entry);

    // Return
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile
    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Verify code was generated
    try testing.expect(code.code.items.len > 0);
}

// Test call with single return value
test "Call marshaling: external call with i32 return" {
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    // fn() -> i32
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "test_call_i32_ret", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Create a call signature for external function
    var call_sig = Signature.init(testing.allocator, .fast);
    defer call_sig.deinit();
    try call_sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    // Call external function
    const call_sig_ref = try func.dfg.makeSig(call_sig);
    const call_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = call_sig_ref,
            .args = &.{},
        },
    };
    const call_inst = try func.dfg.makeInst(call_data);
    const call_result = try func.dfg.appendInstResult(call_inst, Type.I32);
    try func.layout.appendInst(call_inst, entry);

    // Return the call result
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = call_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile
    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Verify code was generated
    try testing.expect(code.code.items.len > 0);
}

// Test call with f64 return
test "Call marshaling: external call with f64 return" {
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    // fn() -> f64
    try sig.returns.append(testing.allocator, AbiParam.new(Type.F64));

    var func = try Function.init(testing.allocator, "test_call_f64_ret", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Create a call signature for external function
    var call_sig = Signature.init(testing.allocator, .fast);
    defer call_sig.deinit();
    try call_sig.returns.append(testing.allocator, AbiParam.new(Type.F64));

    // Call external function
    const call_sig_ref = try func.dfg.makeSig(call_sig);
    const call_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = call_sig_ref,
            .args = &.{},
        },
    };
    const call_inst = try func.dfg.makeInst(call_data);
    const call_result = try func.dfg.appendInstResult(call_inst, Type.F64);
    try func.layout.appendInst(call_inst, entry);

    // Return the call result
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = call_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile
    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Verify code was generated
    try testing.expect(code.code.items.len > 0);
}
