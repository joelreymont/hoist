const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const CallConv = hoist.signature.CallConv;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const ValueList = hoist.value_list.ValueList;
const SigRef = hoist.entities.SigRef;
const ExternalName = hoist.ir.extfunc.ExternalName;
const compile_mod = @import("hoist").codegen.compile;

/// Test that call with wrong parameter count is caught during lowering.
test "signature validation - wrong param count" {
    // Create a signature: fn(i32, i32) -> i32
    var expected_sig = Signature.init(testing.allocator, .fast);
    defer expected_sig.deinit();

    const i32_type = Type{ .int = .{ .width = 32 } };
    const i64_type = Type{ .int = .{ .width = 64 } };

    try expected_sig.params.append(AbiParam.new(i32_type));
    try expected_sig.params.append(AbiParam.new(i32_type));
    try expected_sig.returns.append(AbiParam.new(i32_type));

    // Create a caller function: fn() -> i32
    var caller_sig = Signature.init(testing.allocator, .fast);
    defer caller_sig.deinit();
    try caller_sig.returns.append(AbiParam.new(i32_type));

    var func = try Function.init(testing.allocator, "test_wrong_count", caller_sig);
    defer func.deinit();

    // Register the expected signature in the function
    const sig_ref = SigRef.new(0);
    try func.signatures.set(testing.allocator, sig_ref, expected_sig);

    // Build IR: call external function with wrong number of args
    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Create iconst for arguments
    const const_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = .{ .value = 42 },
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const arg_val = try func.dfg.appendInstResult(const_inst, i32_type);
    try func.layout.appendInst(const_inst, entry);

    // Build call with only 1 argument (expected 2)
    var call_args = ValueList.default();
    try func.dfg.value_lists.push(&call_args, arg_val);

    const ext_name = ExternalName.fromUser(0, 1);
    const call_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = undefined, // Not used when sig_ref is provided
            .args = call_args,
        },
    };
    const call_inst = try func.dfg.makeInst(call_data);
    const call_result = try func.dfg.appendInstResult(call_inst, i32_type);
    try func.layout.appendInst(call_inst, entry);

    // Return
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = call_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Attempt to compile - should fail with signature mismatch
    const result = compile_mod.compileFunction(testing.allocator, &func, .aarch64);

    // Expect compilation to fail due to argument count mismatch
    try testing.expectError(error.SignatureArgumentCountMismatch, result);
}

/// Test that call with wrong parameter types is caught during lowering.
test "signature validation - wrong param types" {
    // Create a signature: fn(i32, i32) -> i32
    var expected_sig = Signature.init(testing.allocator, .fast);
    defer expected_sig.deinit();

    const i32_type = Type{ .int = .{ .width = 32 } };
    const i64_type = Type{ .int = .{ .width = 64 } };

    try expected_sig.params.append(AbiParam.new(i32_type));
    try expected_sig.params.append(AbiParam.new(i32_type));
    try expected_sig.returns.append(AbiParam.new(i32_type));

    // Create a caller function
    var caller_sig = Signature.init(testing.allocator, .fast);
    defer caller_sig.deinit();
    try caller_sig.returns.append(AbiParam.new(i32_type));

    var func = try Function.init(testing.allocator, "test_wrong_types", caller_sig);
    defer func.deinit();

    // Register the expected signature
    const sig_ref = SigRef.new(0);
    try func.signatures.set(testing.allocator, sig_ref, expected_sig);

    // Build IR: call with i64 argument instead of i32
    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Create i32 const for first arg
    const const32_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = .{ .value = 42 },
        },
    };
    const const32_inst = try func.dfg.makeInst(const32_data);
    const arg1_val = try func.dfg.appendInstResult(const32_inst, i32_type);
    try func.layout.appendInst(const32_inst, entry);

    // Create i64 const for second arg (wrong type!)
    const const64_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = .{ .value = 100 },
        },
    };
    const const64_inst = try func.dfg.makeInst(const64_data);
    const arg2_val = try func.dfg.appendInstResult(const64_inst, i64_type);
    try func.layout.appendInst(const64_inst, entry);

    // Build call with mismatched types
    var call_args = ValueList.default();
    try func.dfg.value_lists.push(&call_args, arg1_val);
    try func.dfg.value_lists.push(&call_args, arg2_val); // i64 instead of i32

    const ext_name = ExternalName.fromUser(0, 1);
    const call_data = InstructionData{
        .call = .{
            .opcode = .call,
            .func_ref = undefined,
            .args = call_args,
        },
    };
    const call_inst = try func.dfg.makeInst(call_data);
    const call_result = try func.dfg.appendInstResult(call_inst, i32_type);
    try func.layout.appendInst(call_inst, entry);

    // Return
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = call_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Attempt to compile - should fail with type mismatch
    const result = compile_mod.compileFunction(testing.allocator, &func, .aarch64);

    // Expect compilation to fail due to argument type mismatch
    try testing.expectError(error.SignatureArgumentTypeMismatch, result);
}
