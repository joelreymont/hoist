const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const CallConv = hoist.signature.CallConv;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const ContextBuilder = hoist.context.ContextBuilder;
const FuncRef = hoist.entities.FuncRef;

// AAPCS64 stack argument rules:
// - First 8 integer arguments: X0-X7
// - First 8 float arguments: V0-V7
// - Additional arguments: pushed to stack in order
// - Stack must be 16-byte aligned
// - Each stack slot is 8 bytes (or rounded up for smaller types)

// Test 1: 9 integer arguments (last one goes to stack)
test "stack args: 9 integers - last on stack" {
    const allocator = testing.allocator;

    // Signature: fn many_args(a0, a1, a2, a3, a4, a5, a6, a7, a8: i32) -> i32
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    const i32_type = Type.I32;

    // Add 9 i32 parameters
    var i: usize = 0;
    while (i < 9) : (i += 1) {
        try sig.params.append(allocator, AbiParam.new(i32_type));
    }
    try sig.returns.append(allocator, AbiParam.new(i32_type));

    var func = try Function.init(allocator, "many_int_args", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Return the 9th argument (should come from stack)
    const arg8 = func.dfg.blockParams(entry)[8];
    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{arg8}),
        },
    });

    try func.dfg.appendInst(entry, ret);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("many_int_args", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify args 0-7 in X0-X7, arg 8 loaded from [SP, #offset]
    // TODO: Verify stack frame allocated to accommodate overflow args
}

// Test 2: 10 integer arguments (last two on stack)
test "stack args: 10 integers - last two on stack" {
    const allocator = testing.allocator;

    // Signature: fn many_args(a0..a9: i32) -> i32
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    const i32_type = Type.I32;

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try sig.params.append(allocator, AbiParam.new(i32_type));
    }
    try sig.returns.append(allocator, AbiParam.new(i32_type));

    var func = try Function.init(allocator, "many_int_args10", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Sum the last two arguments (both from stack)
    const arg8 = func.dfg.blockParams(entry)[8];
    const arg9 = func.dfg.blockParams(entry)[9];

    const sum = try func.dfg.makeInst(.{
        .binary = .{
            .opcode = .iadd,
            .args = [2]hoist.value.Value{ arg8, arg9 },
        },
    });
    try func.dfg.attachResult(sum, i32_type);

    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{sum}),
        },
    });

    try func.dfg.appendInst(entry, sum);
    try func.dfg.appendInst(entry, ret);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("many_int_args10", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify args 8, 9 loaded from [SP, #0] and [SP, #8]
}

// Test 3: 9 float arguments (last one goes to stack)
test "stack args: 9 floats - last on stack" {
    const allocator = testing.allocator;

    // Signature: fn many_floats(a0..a8: f64) -> f64
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    const f64_type = Type.F64;

    var i: usize = 0;
    while (i < 9) : (i += 1) {
        try sig.params.append(allocator, AbiParam.new(f64_type));
    }
    try sig.returns.append(allocator, AbiParam.new(f64_type));

    var func = try Function.init(allocator, "many_float_args", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Return the 9th argument (should come from stack)
    const arg8 = func.dfg.blockParams(entry)[8];
    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{arg8}),
        },
    });

    try func.dfg.appendInst(entry, ret);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("many_float_args", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify args 0-7 in V0-V7, arg 8 loaded from [SP, #offset]
}

// Test 4: Mixed int and float with overflow
test "stack args: mixed types with stack overflow" {
    const allocator = testing.allocator;

    // Signature: fn mixed(i0..i7: i32, f0..f7: f64, i8: i32, f8: f64) -> i32
    // This tests that int and float overflow is tracked independently
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    const i32_type = Type.I32;
    const f64_type = Type.F64;

    // 8 integers (X0-X7)
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        try sig.params.append(allocator, AbiParam.new(i32_type));
    }

    // 8 floats (V0-V7)
    i = 0;
    while (i < 8) : (i += 1) {
        try sig.params.append(allocator, AbiParam.new(f64_type));
    }

    // 1 more integer (stack)
    try sig.params.append(allocator, AbiParam.new(i32_type));

    // 1 more float (stack)
    try sig.params.append(allocator, AbiParam.new(f64_type));

    try sig.returns.append(allocator, AbiParam.new(i32_type));

    var func = try Function.init(allocator, "mixed_overflow", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Return the 9th integer (index 16 - after 8 ints + 8 floats)
    const overflow_int = func.dfg.blockParams(entry)[16];
    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{overflow_int}),
        },
    });

    try func.dfg.appendInst(entry, ret);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("mixed_overflow", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify int and float overflow tracked separately
    // TODO: Verify both overflow args on stack at correct offsets
}

// Test 5: Calling function with many arguments
test "stack args: call with stack arguments" {
    const allocator = testing.allocator;

    // Callee signature: fn callee(a0..a9: i32) -> i32
    var callee_sig = Signature.init(allocator, .system_v);
    defer callee_sig.deinit();

    const i32_type = Type.I32;

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try callee_sig.params.append(allocator, AbiParam.new(i32_type));
    }
    try callee_sig.returns.append(allocator, AbiParam.new(i32_type));

    // Caller signature: fn caller(x: i32) -> i32
    var caller_sig = Signature.init(allocator, .system_v);
    defer caller_sig.deinit();

    try caller_sig.params.append(allocator, AbiParam.new(i32_type));
    try caller_sig.returns.append(allocator, AbiParam.new(i32_type));

    var func = try Function.init(allocator, "caller_many_args", caller_sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const x = func.dfg.blockParams(entry)[0];

    // Create constants for other arguments
    var args_array: [10]hoist.value.Value = undefined;
    args_array[0] = x;

    i = 1;
    while (i < 10) : (i += 1) {
        const const_val = try func.dfg.makeInst(.{
            .iconst = .{
                .opcode = .iconst,
                .ty = i32_type,
                .imm = hoist.immediates.Imm64.new(@as(i64, @intCast(i))),
            },
        });
        try func.dfg.attachResult(const_val, i32_type);
        try func.dfg.appendInst(entry, const_val);
        args_array[i] = const_val;
    }

    // Call callee with 10 arguments
    const callee_ref = FuncRef.new(1);
    const call_inst = try func.dfg.makeInst(.{
        .call = .{
            .opcode = .call,
            .func_ref = callee_ref,
            .args_storage = try func.dfg.allocateValueList(&args_array),
        },
    });
    try func.dfg.attachResult(call_inst, i32_type);

    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{call_inst}),
        },
    });

    try func.dfg.appendInst(entry, call_inst);
    try func.dfg.appendInst(entry, ret);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("caller_many_args", caller_sig);
    _ = try ctx_builder.registerFunction("callee", callee_sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify caller stores args 8, 9 to stack before BL
    // TODO: Verify stack pointer adjusted for outgoing args
    // TODO: Verify 16-byte stack alignment maintained
}

// Test 6: Large number of arguments (stress test)
test "stack args: 16 arguments stress test" {
    const allocator = testing.allocator;

    // Signature: fn stress(a0..a15: i64) -> i64
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    const i64_type = Type.I64;

    var i: usize = 0;
    while (i < 16) : (i += 1) {
        try sig.params.append(allocator, AbiParam.new(i64_type));
    }
    try sig.returns.append(allocator, AbiParam.new(i64_type));

    var func = try Function.init(allocator, "stress_many_args", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Return the last argument (15th, deeply on stack)
    const last_arg = func.dfg.blockParams(entry)[15];
    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{last_arg}),
        },
    });

    try func.dfg.appendInst(entry, ret);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("stress_many_args", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify 8 stack slots allocated (args 8-15)
    // TODO: Verify correct offset calculation for arg 15: [SP, #56]
}

// Test 7: Small types on stack (i8, i16 arguments)
test "stack args: small integer types" {
    const allocator = testing.allocator;

    // Signature: fn small_types(i0..i7: i32, b0: i8, b1: i16) -> i32
    // Small types are promoted to 8 bytes on stack per AAPCS64
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    const i32_type = Type.I32;
    const i8_type = Type.I8;
    const i16_type = Type.I16;

    // 8 regular ints
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        try sig.params.append(allocator, AbiParam.new(i32_type));
    }

    // Small types that will go to stack
    try sig.params.append(allocator, AbiParam.new(i8_type));
    try sig.params.append(allocator, AbiParam.new(i16_type));

    try sig.returns.append(allocator, AbiParam.new(i32_type));

    var func = try Function.init(allocator, "small_type_overflow", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Just return constant
    const result = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = i32_type,
            .imm = hoist.immediates.Imm64.new(42),
        },
    });
    try func.dfg.attachResult(result, i32_type);

    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{result}),
        },
    });

    try func.dfg.appendInst(entry, result);
    try func.dfg.appendInst(entry, ret);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("small_type_overflow", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const compile_result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer compile_result.code.deinit();
    defer compile_result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(compile_result.code.items.len > 0);

    // TODO: Verify i8 and i16 occupy full 8-byte stack slots
    // TODO: Verify proper zero/sign extension when loaded
}
