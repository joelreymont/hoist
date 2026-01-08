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
const Opcode = hoist.opcodes.Opcode;

// Test 1: Simple tail call - function calls itself recursively via return_call
// Validates: Tail call optimization eliminates stack frame growth
test "tail call: simple recursive countdown" {
    const allocator = testing.allocator;

    // Signature: fn countdown(n: i32) -> i32
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    const i32_type = Type.I32;
    try sig.params.append(allocator, AbiParam.new(i32_type));
    try sig.returns.append(allocator, AbiParam.new(i32_type));

    var func = try Function.init(allocator, "countdown", sig);
    defer func.deinit();

    // Create blocks
    const entry = try func.dfg.makeBlock();
    const base_case = try func.dfg.makeBlock();
    const recursive_case = try func.dfg.makeBlock();

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(base_case);
    try func.layout.appendBlock(recursive_case);

    // Entry: if n <= 0 goto base_case else goto recursive_case
    const n = func.dfg.blockParams(entry)[0];
    const zero = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = i32_type,
            .imm = hoist.immediates.Imm64.new(0),
        },
    });
    const cond = try func.dfg.makeInst(.{
        .binary = .{
            .opcode = .icmp,
            .args = [2]hoist.value.Value{ n, zero },
            .imm = hoist.immediates.Imm64.new(@intFromEnum(hoist.IntCC.sle)),
        },
    });
    try func.dfg.attachResult(zero, i32_type);
    try func.dfg.attachResult(cond, Type.I8);

    const br = try func.dfg.makeInst(.{
        .branch = .{
            .opcode = .brif,
            .destination = base_case,
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{cond}),
            .data = .{ .branch_data = .{
                .else_destination = recursive_case,
            } },
        },
    });

    try func.dfg.appendInst(entry, zero);
    try func.dfg.appendInst(entry, cond);
    try func.dfg.appendInst(entry, br);

    // Base case: return 0
    const ret_zero = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{zero}),
        },
    });
    try func.dfg.appendInst(base_case, ret_zero);

    // Recursive case: return countdown(n - 1)
    const one = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = i32_type,
            .imm = hoist.immediates.Imm64.new(1),
        },
    });
    const n_minus_1 = try func.dfg.makeInst(.{
        .binary = .{
            .opcode = .isub,
            .args = [2]hoist.value.Value{ n, one },
        },
    });
    try func.dfg.attachResult(one, i32_type);
    try func.dfg.attachResult(n_minus_1, i32_type);

    // Tail call to self
    const self_ref = FuncRef.new(0);
    const tail_call = try func.dfg.makeInst(.{
        .call = .{
            .opcode = .return_call,
            .func_ref = self_ref,
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{n_minus_1}),
        },
    });

    try func.dfg.appendInst(recursive_case, one);
    try func.dfg.appendInst(recursive_case, n_minus_1);
    try func.dfg.appendInst(recursive_case, tail_call);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    // Register the function
    _ = try ctx_builder.registerFunction("countdown", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code was generated
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify no BL instruction to self (should be B or BR)
    // TODO: Verify frame is deallocated before jump
}

// Test 2: Tail call with different signature (more arguments)
// Validates: Tail call with different frame sizes works correctly
test "tail call: to function with more arguments" {
    const allocator = testing.allocator;

    // Caller signature: fn caller(a: i32) -> i32
    var caller_sig = Signature.init(allocator, .system_v);
    defer caller_sig.deinit();

    const i32_type = Type.I32;
    try caller_sig.params.append(allocator, AbiParam.new(i32_type));
    try caller_sig.returns.append(allocator, AbiParam.new(i32_type));

    // Callee signature: fn callee(a: i32, b: i32, c: i32) -> i32
    var callee_sig = Signature.init(allocator, .system_v);
    defer callee_sig.deinit();

    try callee_sig.params.append(allocator, AbiParam.new(i32_type));
    try callee_sig.params.append(allocator, AbiParam.new(i32_type));
    try callee_sig.params.append(allocator, AbiParam.new(i32_type));
    try callee_sig.returns.append(allocator, AbiParam.new(i32_type));

    var func = try Function.init(allocator, "test_caller", caller_sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const param_a = func.dfg.blockParams(entry)[0];

    // Create constants for b and c
    const const_b = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = i32_type,
            .imm = hoist.immediates.Imm64.new(42),
        },
    });
    const const_c = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = i32_type,
            .imm = hoist.immediates.Imm64.new(99),
        },
    });
    try func.dfg.attachResult(const_b, i32_type);
    try func.dfg.attachResult(const_c, i32_type);

    // Tail call to callee(a, 42, 99)
    const callee_ref = FuncRef.new(1);
    const tail_call = try func.dfg.makeInst(.{
        .call = .{
            .opcode = .return_call,
            .func_ref = callee_ref,
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{ param_a, const_b, const_c }),
        },
    });

    try func.dfg.appendInst(entry, const_b);
    try func.dfg.appendInst(entry, const_c);
    try func.dfg.appendInst(entry, tail_call);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("test_caller", caller_sig);
    _ = try ctx_builder.registerFunction("callee", callee_sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code was generated
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify proper argument marshaling to X0, X1, X2
    // TODO: Verify frame deallocated before jump
}

// Test 3: Indirect tail call
// Validates: Tail calls through function pointers work
test "tail call: indirect through function pointer" {
    const allocator = testing.allocator;

    // Signature: fn caller(fn_ptr: *fn(i32) -> i32, arg: i32) -> i32
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    const i32_type = Type.I32;
    const ptr_type = Type{ .ptr = .{ .pointee = 0 } }; // Simplified

    try sig.params.append(allocator, AbiParam.new(ptr_type));
    try sig.params.append(allocator, AbiParam.new(i32_type));
    try sig.returns.append(allocator, AbiParam.new(i32_type));

    var func = try Function.init(allocator, "indirect_caller", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const fn_ptr = func.dfg.blockParams(entry)[0];
    const arg = func.dfg.blockParams(entry)[1];

    // Create target signature for indirect call
    var target_sig = Signature.init(allocator, .system_v);
    defer target_sig.deinit();
    try target_sig.params.append(allocator, AbiParam.new(i32_type));
    try target_sig.returns.append(allocator, AbiParam.new(i32_type));

    const sig_ref = try func.dfg.importSignature(target_sig);

    // Indirect tail call: return fn_ptr(arg)
    const tail_call = try func.dfg.makeInst(.{
        .call_indirect = .{
            .opcode = .return_call_indirect,
            .sig_ref = sig_ref,
            .callee = fn_ptr,
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{arg}),
        },
    });

    try func.dfg.appendInst(entry, tail_call);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("indirect_caller", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code was generated
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify BR (not BLR) is used for tail call
    // TODO: Verify frame deallocated before jump
}

// Test 4: Tail call with float arguments
// Validates: Tail calls handle float ABI correctly
test "tail call: with floating point arguments" {
    const allocator = testing.allocator;

    // Signature: fn caller(x: f64) -> f64
    var caller_sig = Signature.init(allocator, .system_v);
    defer caller_sig.deinit();

    const f64_type = Type.F64;
    try caller_sig.params.append(allocator, AbiParam.new(f64_type));
    try caller_sig.returns.append(allocator, AbiParam.new(f64_type));

    // Callee signature: fn callee(a: f64, b: f64) -> f64
    var callee_sig = Signature.init(allocator, .system_v);
    defer callee_sig.deinit();

    try callee_sig.params.append(allocator, AbiParam.new(f64_type));
    try callee_sig.params.append(allocator, AbiParam.new(f64_type));
    try callee_sig.returns.append(allocator, AbiParam.new(f64_type));

    var func = try Function.init(allocator, "fp_caller", caller_sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const param_x = func.dfg.blockParams(entry)[0];

    // Create constant for second argument
    const const_pi = try func.dfg.makeInst(.{
        .fconst = .{
            .opcode = .fconst,
            .ty = f64_type,
            .imm = hoist.immediates.Imm64.new(@bitCast(@as(f64, 3.14159))),
        },
    });
    try func.dfg.attachResult(const_pi, f64_type);

    // Tail call to callee(x, 3.14159)
    const callee_ref = FuncRef.new(1);
    const tail_call = try func.dfg.makeInst(.{
        .call = .{
            .opcode = .return_call,
            .func_ref = callee_ref,
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{ param_x, const_pi }),
        },
    });

    try func.dfg.appendInst(entry, const_pi);
    try func.dfg.appendInst(entry, tail_call);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("fp_caller", caller_sig);
    _ = try ctx_builder.registerFunction("callee", callee_sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code was generated
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify V0, V1 used for float arguments
    // TODO: Verify frame deallocated before jump
}

// Test 5: Non-tail call followed by tail call
// Validates: Mix of regular and tail calls in same function
test "tail call: mixed with regular calls" {
    const allocator = testing.allocator;

    // Signature: fn caller(n: i32) -> i32
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    const i32_type = Type.I32;
    try sig.params.append(allocator, AbiParam.new(i32_type));
    try sig.returns.append(allocator, AbiParam.new(i32_type));

    var func = try Function.init(allocator, "mixed_caller", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const n = func.dfg.blockParams(entry)[0];

    // Regular call: temp = helper(n)
    const helper_ref = FuncRef.new(1);
    const regular_call = try func.dfg.makeInst(.{
        .call = .{
            .opcode = .call,
            .func_ref = helper_ref,
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{n}),
        },
    });
    try func.dfg.attachResult(regular_call, i32_type);

    // Tail call: return process(temp)
    const process_ref = FuncRef.new(2);
    const tail_call = try func.dfg.makeInst(.{
        .call = .{
            .opcode = .return_call,
            .func_ref = process_ref,
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{regular_call}),
        },
    });

    try func.dfg.appendInst(entry, regular_call);
    try func.dfg.appendInst(entry, tail_call);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("mixed_caller", sig);
    _ = try ctx_builder.registerFunction("helper", sig);
    _ = try ctx_builder.registerFunction("process", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code was generated
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify first call uses BL (link register saved)
    // TODO: Verify second call uses B (no link, frame deallocated)
}
