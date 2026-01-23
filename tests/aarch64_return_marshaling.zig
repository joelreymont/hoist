const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const Ieee64 = hoist.immediates.Ieee64;
const Ieee64 = hoist.immediates.Ieee64;
const ContextBuilder = hoist.context.ContextBuilder;
const ExternalName = hoist.entities.ExternalName;

// Test single integer return (X0)
test "Return marshaling: single i32 in X0" {
    var sig = Signature.init(testing.allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it

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
    // Note: sig ownership transfers to func, func.deinit() frees it

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
            .imm = Ieee64.fromF64(3.14),
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
    // Note: sig ownership transfers to func, func.deinit() frees it

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
    // Note: sig ownership transfers to func, func.deinit() frees it

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
    // Note: sig ownership transfers to func, func.deinit() frees it

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

// Test multi-return: two i32 values in X0 and X1
test "Return marshaling: multi i32 in X0+X1" {
    var sig = Signature.init(testing.allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it

    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "test_multi_i32", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const val1_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(10),
        },
    };
    const val1_inst = try func.dfg.makeInst(val1_data);
    const val1 = try func.dfg.appendInstResult(val1_inst, Type.I32);
    try func.layout.appendInst(val1_inst, entry);

    const val2_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(20),
        },
    };
    const val2_inst = try func.dfg.makeInst(val2_data);
    const val2 = try func.dfg.appendInstResult(val2_inst, Type.I32);
    try func.layout.appendInst(val2_inst, entry);

    const ret_data = InstructionData{
        .binary = .{
            .opcode = .@"return",
            .args = .{ val1, val2 },
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test multi-return: i64 in X0 and f64 in V0
test "Return marshaling: mixed i64+f64 in X0+V0" {
    var sig = Signature.init(testing.allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it

    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.F64));

    var func = try Function.init(testing.allocator, "test_mixed_ret", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const int_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(100),
        },
    };
    const int_inst = try func.dfg.makeInst(int_data);
    const int_val = try func.dfg.appendInstResult(int_inst, Type.I64);
    try func.layout.appendInst(int_inst, entry);

    const fp_data = InstructionData{
        .unary_imm = .{
            .opcode = .f64const,
            .imm = Ieee64.fromF64(2.5),
        },
    };
    const fp_inst = try func.dfg.makeInst(fp_data);
    const fp_val = try func.dfg.appendInstResult(fp_inst, Type.F64);
    try func.layout.appendInst(fp_inst, entry);

    const ret_data = InstructionData{
        .binary = .{
            .opcode = .@"return",
            .args = .{ int_val, fp_val },
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test HFA return: 2 f32 fields in V0-V1
test "Return marshaling: HFA 2xf32 in V0+V1" {
    const abi_mod = @import("hoist").machinst.abi;

    const fields = [_]abi_mod.StructField{
        .{ .ty = abi_mod.Type.f32, .offset = 0 },
        .{ .ty = abi_mod.Type.f32, .offset = 4 },
    };
    const hfa_type = Type{ .@"struct" = &fields };

    var sig = Signature.init(testing.allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it

    try sig.returns.append(testing.allocator, AbiParam.new(hfa_type));

    var func = try Function.init(testing.allocator, "test_hfa_ret", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Create struct on stack
    const stack_data = InstructionData{
        .stack_alloc = .{
            .opcode = .stack_alloc,
            .size = 8,
            .align_bytes = 4,
        },
    };
    const stack_inst = try func.dfg.makeInst(stack_data);
    const stack_ptr = try func.dfg.appendInstResult(stack_inst, Type{ .ptr = .{ .pointee = 0 } });
    try func.layout.appendInst(stack_inst, entry);

    // Store field 1
    const f1_data = InstructionData{
        .unary_imm = .{
            .opcode = .f32const,
            .imm = Imm64.fromF32(1.5),
        },
    };
    const f1_inst = try func.dfg.makeInst(f1_data);
    const f1_val = try func.dfg.appendInstResult(f1_inst, Type.F32);
    try func.layout.appendInst(f1_inst, entry);

    const store1_data = InstructionData{
        .store = .{
            .opcode = .store,
            .address = stack_ptr,
            .value = f1_val,
            .offset = 0,
            .flags = .{},
        },
    };
    const store1_inst = try func.dfg.makeInst(store1_data);
    try func.layout.appendInst(store1_inst, entry);

    // Store field 2
    const f2_data = InstructionData{
        .unary_imm = .{
            .opcode = .f32const,
            .imm = Imm64.fromF32(2.5),
        },
    };
    const f2_inst = try func.dfg.makeInst(f2_data);
    const f2_val = try func.dfg.appendInstResult(f2_inst, Type.F32);
    try func.layout.appendInst(f2_inst, entry);

    const store2_data = InstructionData{
        .store = .{
            .opcode = .store,
            .address = stack_ptr,
            .value = f2_val,
            .offset = 4,
            .flags = .{},
        },
    };
    const store2_inst = try func.dfg.makeInst(store2_data);
    try func.layout.appendInst(store2_inst, entry);

    // Load struct as return value
    const load_data = InstructionData{
        .load = .{
            .opcode = .load,
            .ty = hfa_type,
            .address = stack_ptr,
            .offset = 0,
            .flags = .{},
        },
    };
    const load_inst = try func.dfg.makeInst(load_data);
    const load_val = try func.dfg.appendInstResult(load_inst, hfa_type);
    try func.layout.appendInst(load_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = load_val,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}
