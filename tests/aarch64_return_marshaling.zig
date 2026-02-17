const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const StructField = hoist.types.StructField;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const Ieee64 = hoist.immediates.Ieee64;
const ContextBuilder = hoist.context.ContextBuilder;
const ExternalName = hoist.extfunc.ExternalName;
const a64_abi = hoist.aarch64_abi;

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

    defer ctx.deinit();
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
            .imm = Imm64.new(@as(i64, @bitCast(@as(u64, Ieee64.fromF64(3.14).toBits())))),
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

    defer ctx.deinit();
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

    defer ctx.deinit();
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
    try call_sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    // Call external function
    const call_sig_ref = try func.addSignature(call_sig);
    const call_name = try ExternalName.fromTestcase(testing.allocator, "ext_call_i32");
    const func_ref = try func.func_metadata.registerExternalFunc(call_name, call_sig_ref, .import);
    const call_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = func_ref,
            .args = .{},
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

    defer ctx.deinit();
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
    try call_sig.returns.append(testing.allocator, AbiParam.new(Type.F64));

    // Call external function
    const call_sig_ref = try func.addSignature(call_sig);
    const call_name = try ExternalName.fromTestcase(testing.allocator, "ext_call_f64");
    const func_ref = try func.func_metadata.registerExternalFunc(call_name, call_sig_ref, .import);
    const call_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = func_ref,
            .args = .{},
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

    defer ctx.deinit();
    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Verify code was generated
    try testing.expect(code.code.items.len > 0);
}

// Test call with multi-return: two i32 values in X0 and X1
test "Call marshaling: external call with multi i32 returns" {
    var sig = Signature.init(testing.allocator, .fast);
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "test_call_multi_i32_ret", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    var call_sig = Signature.init(testing.allocator, .fast);
    try call_sig.returns.append(testing.allocator, AbiParam.new(Type.I32));
    try call_sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    const call_sig_ref = try func.addSignature(call_sig);
    const call_name = try ExternalName.fromTestcase(testing.allocator, "ext_call_multi_i32");
    const func_ref = try func.func_metadata.registerExternalFunc(call_name, call_sig_ref, .import);
    const call_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = func_ref,
            .args = .{},
        },
    };
    const call_inst = try func.dfg.makeInst(call_data);
    const call_result0 = try func.dfg.appendInstResult(call_inst, Type.I32);
    const call_result1 = try func.dfg.appendInstResult(call_inst, Type.I32);
    try func.layout.appendInst(call_inst, entry);

    var ret_args = hoist.value_list.ValueList.default();
    try func.dfg.value_lists.extend(&ret_args, &.{ call_result0, call_result1 });
    const ret_data = InstructionData{
        .@"return" = .{
            .opcode = .@"return",
            .args = ret_args,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    defer ctx.deinit();
    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test call with multi-return: i64 in X0 and f64 in V0
test "Call marshaling: external call with mixed i64+f64 returns" {
    var sig = Signature.init(testing.allocator, .fast);
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.F64));

    var func = try Function.init(testing.allocator, "test_call_mixed_ret", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    var call_sig = Signature.init(testing.allocator, .fast);
    try call_sig.returns.append(testing.allocator, AbiParam.new(Type.I64));
    try call_sig.returns.append(testing.allocator, AbiParam.new(Type.F64));

    const call_sig_ref = try func.addSignature(call_sig);
    const call_name = try ExternalName.fromTestcase(testing.allocator, "ext_call_mixed_ret");
    const func_ref = try func.func_metadata.registerExternalFunc(call_name, call_sig_ref, .import);
    const call_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = func_ref,
            .args = .{},
        },
    };
    const call_inst = try func.dfg.makeInst(call_data);
    const call_int = try func.dfg.appendInstResult(call_inst, Type.I64);
    const call_fp = try func.dfg.appendInstResult(call_inst, Type.F64);
    try func.layout.appendInst(call_inst, entry);

    var ret_args = hoist.value_list.ValueList.default();
    try func.dfg.value_lists.extend(&ret_args, &.{ call_int, call_fp });
    const ret_data = InstructionData{
        .@"return" = .{
            .opcode = .@"return",
            .args = ret_args,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    defer ctx.deinit();
    var code = try ctx.compileFunction(&func);
    defer code.deinit();

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

    var ret_args = hoist.value_list.ValueList.default();
    try func.dfg.value_lists.extend(&ret_args, &.{ val1, val2 });
    const ret_data = InstructionData{
        .@"return" = .{
            .opcode = .@"return",
            .args = ret_args,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    defer ctx.deinit();
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
            .imm = Imm64.new(@as(i64, @bitCast(@as(u64, Ieee64.fromF64(2.5).toBits())))),
        },
    };
    const fp_inst = try func.dfg.makeInst(fp_data);
    const fp_val = try func.dfg.appendInstResult(fp_inst, Type.F64);
    try func.layout.appendInst(fp_inst, entry);

    var ret_args = hoist.value_list.ValueList.default();
    try func.dfg.value_lists.extend(&ret_args, &.{ int_val, fp_val });
    const ret_data = InstructionData{
        .@"return" = .{
            .opcode = .@"return",
            .args = ret_args,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    defer ctx.deinit();
    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

test "Return marshaling: classify HFA f64x2 in V0-V1" {
    const fields = [_]StructField{
        .{ .ty = Type.F64, .offset = 0 },
        .{ .ty = Type.F64, .offset = 8 },
    };
    var struct_store = hoist.types.StructStore.init(testing.allocator);
    defer struct_store.deinit();
    const struct_id = try struct_store.intern(&fields, 16);
    const hfa_ty = Type.fromStructId(struct_id);
    const ret_loc = a64_abi.classifyReturn(hfa_ty, &struct_store);

    try testing.expect(ret_loc == .hfa);
    try testing.expectEqual(@as(u8, 2), ret_loc.hfa.count);
    try testing.expectEqual(@as(u6, 0), ret_loc.hfa.regs[0].hwEnc());
    try testing.expectEqual(@as(u6, 1), ret_loc.hfa.regs[1].hwEnc());
}
