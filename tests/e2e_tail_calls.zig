const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const ContextBuilder = hoist.context.ContextBuilder;
const InstructionData = hoist.instruction_data.InstructionData;
const ValueList = hoist.value_list.ValueList;
const FuncRef = hoist.entities.FuncRef;
const SigRef = hoist.entities.SigRef;
const ExternalName = hoist.extfunc.ExternalName;
const Imm64 = hoist.immediates.Imm64;

const Allocator = std.mem.Allocator;

fn addSig(func: *Function, allocator: Allocator, sig: *const Signature) !SigRef {
    const idx = func.signatures.elems.items.len;
    var copy = Signature.init(allocator, sig.call_conv);
    try copy.params.appendSlice(allocator, sig.params.items);
    try copy.returns.appendSlice(allocator, sig.returns.items);
    try func.signatures.elems.append(allocator, copy);
    return SigRef.new(@intCast(idx));
}

fn regExt(func: *Function, allocator: Allocator, name: []const u8, sig: *const Signature) !FuncRef {
    const sig_ref = try addSig(func, allocator, sig);
    const ext_name = try ExternalName.fromTestcase(allocator, name);
    return try func.func_metadata.registerExternalFunc(ext_name, sig_ref, .import);
}

// Test 1: Simple tail call - function calls itself recursively via return_call
// Validates: Tail call optimization eliminates stack frame growth
// Note: This test verifies lowering does not crash and emits code.
test "tail call: simple recursive countdown" {
    const allocator = testing.allocator;

    // Signature: fn countdown(n: i32) -> i32
    var sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it

    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "countdown", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    const base_case = try func.dfg.makeBlock();
    const recursive_case = try func.dfg.makeBlock();

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(base_case);
    try func.layout.appendBlock(recursive_case);

    const n = try func.dfg.appendBlockParam(entry, Type.I32);

    const zero_data = InstructionData{ .unary_imm = .{ .opcode = .iconst, .imm = Imm64.new(0) } };
    const zero_inst = try func.dfg.makeInst(zero_data);
    const zero_val = try func.dfg.appendInstResult(zero_inst, Type.I32);
    try func.layout.appendInst(zero_inst, entry);

    const cmp_data = InstructionData{ .int_compare = .{ .opcode = .icmp, .cond = .sle, .args = .{ n, zero_val } } };
    const cmp_inst = try func.dfg.makeInst(cmp_data);
    const cmp_val = try func.dfg.appendInstResult(cmp_inst, Type.I8);
    try func.layout.appendInst(cmp_inst, entry);

    const br_data = InstructionData{ .branch = .{ .opcode = .brif, .condition = cmp_val, .then_dest = base_case, .else_dest = recursive_case } };
    const br_inst = try func.dfg.makeInst(br_data);
    try func.layout.appendInst(br_inst, entry);

    const ret_zero = InstructionData{ .unary = .{ .opcode = .@"return", .arg = zero_val } };
    const ret_inst = try func.dfg.makeInst(ret_zero);
    try func.layout.appendInst(ret_inst, base_case);

    const one_data = InstructionData{ .unary_imm = .{ .opcode = .iconst, .imm = Imm64.new(1) } };
    const one_inst = try func.dfg.makeInst(one_data);
    const one_val = try func.dfg.appendInstResult(one_inst, Type.I32);
    try func.layout.appendInst(one_inst, recursive_case);

    const sub_data = InstructionData{ .binary = .{ .opcode = .isub, .args = .{ n, one_val } } };
    const sub_inst = try func.dfg.makeInst(sub_data);
    const n_minus_1 = try func.dfg.appendInstResult(sub_inst, Type.I32);
    try func.layout.appendInst(sub_inst, recursive_case);

    const self_ref = try regExt(&func, allocator, "countdown", &func.sig);
    var call_args = ValueList.default();
    try func.dfg.value_lists.push(&call_args, n_minus_1);

    const tail_call = InstructionData{ .call = .{ .opcode = .return_call, .func_ref = self_ref, .args = call_args } };
    const tail_inst = try func.dfg.makeInst(tail_call);
    try func.layout.appendInst(tail_inst, recursive_case);

    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test 2: Tail call with different signature (more arguments)
// Validates: Tail call with different frame sizes works correctly
// Note: This test verifies lowering does not crash and emits code.
test "tail call: to function with more arguments" {
    const allocator = testing.allocator;

    // Caller signature: fn caller(a: i32) -> i32
    var caller_sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func
    try caller_sig.params.append(allocator, AbiParam.new(Type.I32));
    try caller_sig.returns.append(allocator, AbiParam.new(Type.I32));

    // Callee signature: fn callee(a: i32, b: i32, c: i32) -> i32
    var callee_sig = Signature.init(allocator, .system_v);
    defer callee_sig.deinit();
    try callee_sig.params.append(allocator, AbiParam.new(Type.I32));
    try callee_sig.params.append(allocator, AbiParam.new(Type.I32));
    try callee_sig.params.append(allocator, AbiParam.new(Type.I32));
    try callee_sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_caller", caller_sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const param_a = try func.dfg.appendBlockParam(entry, Type.I32);

    const b_data = InstructionData{ .unary_imm = .{ .opcode = .iconst, .imm = Imm64.new(42) } };
    const b_inst = try func.dfg.makeInst(b_data);
    const b_val = try func.dfg.appendInstResult(b_inst, Type.I32);
    try func.layout.appendInst(b_inst, entry);

    const c_data = InstructionData{ .unary_imm = .{ .opcode = .iconst, .imm = Imm64.new(99) } };
    const c_inst = try func.dfg.makeInst(c_data);
    const c_val = try func.dfg.appendInstResult(c_inst, Type.I32);
    try func.layout.appendInst(c_inst, entry);

    const callee_ref = try regExt(&func, allocator, "callee", &callee_sig);
    var call_args = ValueList.default();
    try func.dfg.value_lists.push(&call_args, param_a);
    try func.dfg.value_lists.push(&call_args, b_val);
    try func.dfg.value_lists.push(&call_args, c_val);

    const tail_call = InstructionData{ .call = .{ .opcode = .return_call, .func_ref = callee_ref, .args = call_args } };
    const call_inst = try func.dfg.makeInst(tail_call);
    try func.layout.appendInst(call_inst, entry);

    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test 3: Indirect tail call
// Validates: Tail calls through function pointers work
// Note: This test verifies lowering does not crash and emits code.
test "tail call: indirect through function pointer" {
    const allocator = testing.allocator;

    // Signature: fn caller(fn_ptr: i64, arg: i32) -> i32
    var sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "indirect_caller", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const fn_ptr = try func.dfg.appendBlockParam(entry, Type.I64);
    const arg = try func.dfg.appendBlockParam(entry, Type.I32);

    var target_sig = Signature.init(allocator, .system_v);
    defer target_sig.deinit();
    try target_sig.params.append(allocator, AbiParam.new(Type.I32));
    try target_sig.returns.append(allocator, AbiParam.new(Type.I32));

    const sig_ref = try addSig(&func, allocator, &target_sig);

    var args = ValueList.default();
    try func.dfg.value_lists.push(&args, fn_ptr);
    try func.dfg.value_lists.push(&args, arg);

    const tail_call = InstructionData{ .call_indirect = .{ .opcode = .return_call_indirect, .sig_ref = sig_ref, .args = args } };
    const call_inst = try func.dfg.makeInst(tail_call);
    try func.layout.appendInst(call_inst, entry);

    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test 4: Tail call with float arguments
// Validates: Tail calls handle float ABI correctly
// Note: This test verifies lowering does not crash and emits code.
test "tail call: with floating point arguments" {
    const allocator = testing.allocator;

    // Signature: fn caller(x: f64) -> f64
    var caller_sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func
    try caller_sig.params.append(allocator, AbiParam.new(Type.F64));
    try caller_sig.returns.append(allocator, AbiParam.new(Type.F64));

    // Callee signature: fn callee(a: f64, b: f64) -> f64
    var callee_sig = Signature.init(allocator, .system_v);
    defer callee_sig.deinit();
    try callee_sig.params.append(allocator, AbiParam.new(Type.F64));
    try callee_sig.params.append(allocator, AbiParam.new(Type.F64));
    try callee_sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "fp_caller", caller_sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const param_x = try func.dfg.appendBlockParam(entry, Type.F64);

    const pi_bits: u64 = @bitCast(@as(f64, 3.14159));
    const pi_data = InstructionData{ .unary_imm = .{ .opcode = .f64const, .imm = Imm64.new(@intCast(pi_bits)) } };
    const pi_inst = try func.dfg.makeInst(pi_data);
    const pi_val = try func.dfg.appendInstResult(pi_inst, Type.F64);
    try func.layout.appendInst(pi_inst, entry);

    const callee_ref = try regExt(&func, allocator, "callee", &callee_sig);
    var call_args = ValueList.default();
    try func.dfg.value_lists.push(&call_args, param_x);
    try func.dfg.value_lists.push(&call_args, pi_val);

    const tail_call = InstructionData{ .call = .{ .opcode = .return_call, .func_ref = callee_ref, .args = call_args } };
    const call_inst = try func.dfg.makeInst(tail_call);
    try func.layout.appendInst(call_inst, entry);

    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test 5: Tail call with stack arguments
// Validates: Tail calls marshal stack arguments correctly
// Note: This test verifies lowering does not crash and emits code.
test "tail call: with stack arguments" {
    const allocator = testing.allocator;

    var caller_sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func

    for (0..10) |_| {
        try caller_sig.params.append(allocator, AbiParam.new(Type.I64));
    }
    try caller_sig.returns.append(allocator, AbiParam.new(Type.I64));

    var callee_sig = Signature.init(allocator, .system_v);
    defer callee_sig.deinit();
    for (0..10) |_| {
        try callee_sig.params.append(allocator, AbiParam.new(Type.I64));
    }
    try callee_sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "stack_arg_caller", caller_sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    var args: [10]hoist.entities.Value = undefined;
    for (0..10) |i| {
        args[i] = try func.dfg.appendBlockParam(entry, Type.I64);
    }

    const callee_ref = try regExt(&func, allocator, "stack_arg_callee", &callee_sig);
    var call_args = ValueList.default();
    try func.dfg.value_lists.extend(&call_args, &args);

    const tail_call = InstructionData{ .call = .{ .opcode = .return_call, .func_ref = callee_ref, .args = call_args } };
    const call_inst = try func.dfg.makeInst(tail_call);
    try func.layout.appendInst(call_inst, entry);

    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test 6: Indirect tail call with stack arguments
// Validates: Indirect tail calls handle stack args
// Note: This test verifies lowering does not crash and emits code.
test "tail call: indirect with stack arguments" {
    const allocator = testing.allocator;

    var sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func

    try sig.params.append(allocator, AbiParam.new(Type.I64));
    for (0..10) |_| {
        try sig.params.append(allocator, AbiParam.new(Type.I64));
    }
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "indirect_stack_arg_caller", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    var params: [11]hoist.entities.Value = undefined;
    for (0..11) |i| {
        params[i] = try func.dfg.appendBlockParam(entry, Type.I64);
    }

    var target_sig = Signature.init(allocator, .system_v);
    defer target_sig.deinit();
    for (0..10) |_| {
        try target_sig.params.append(allocator, AbiParam.new(Type.I64));
    }
    try target_sig.returns.append(allocator, AbiParam.new(Type.I64));

    const sig_ref = try addSig(&func, allocator, &target_sig);

    var call_args = ValueList.default();
    try func.dfg.value_lists.extend(&call_args, &params);

    const tail_call = InstructionData{ .call_indirect = .{ .opcode = .return_call_indirect, .sig_ref = sig_ref, .args = call_args } };
    const call_inst = try func.dfg.makeInst(tail_call);
    try func.layout.appendInst(call_inst, entry);

    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test 7: Non-tail call followed by tail call
// Validates: Mix of regular and tail calls in same function
// Note: This test verifies lowering does not crash and emits code.
test "tail call: mixed with regular calls" {
    const allocator = testing.allocator;

    // Signature: fn caller(n: i32) -> i32
    var sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func

    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "mixed_caller", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const n = try func.dfg.appendBlockParam(entry, Type.I32);

    const helper_ref = try regExt(&func, allocator, "helper", &func.sig);
    var helper_args = ValueList.default();
    try func.dfg.value_lists.push(&helper_args, n);

    const helper_call = InstructionData{ .call = .{ .opcode = .call, .func_ref = helper_ref, .args = helper_args } };
    const helper_inst = try func.dfg.makeInst(helper_call);
    const helper_val = try func.dfg.appendInstResult(helper_inst, Type.I32);
    try func.layout.appendInst(helper_inst, entry);

    const process_ref = try regExt(&func, allocator, "process", &func.sig);
    var process_args = ValueList.default();
    try func.dfg.value_lists.push(&process_args, helper_val);

    const tail_call = InstructionData{ .call = .{ .opcode = .return_call, .func_ref = process_ref, .args = process_args } };
    const tail_inst = try func.dfg.makeInst(tail_call);
    try func.layout.appendInst(tail_inst, entry);

    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}
