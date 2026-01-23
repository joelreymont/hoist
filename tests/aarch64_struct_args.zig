const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const CallConv = hoist.signature.CallConv;
const AbiParam = hoist.signature.AbiParam;
const ArgumentPurpose = hoist.signature.ArgumentPurpose;
const Type = hoist.types.Type;
const ContextBuilder = hoist.context.ContextBuilder;
const abi = hoist.abi;

// AAPCS64 struct passing rules:
// 1. Structs <= 16 bytes: passed in registers (1-2 GPRs or 1-4 FP regs for HFA)
// 2. Structs > 16 bytes: passed by reference (pointer in register)
// 3. HFA (Homogeneous Float Aggregate): 1-4 identical float members → V0-V3
// 4. Non-homogeneous small structs: packed into X0-X7

// Test 1: 8-byte integer value passed in single register
test "struct args: 8-byte value in single register" {
    const allocator = testing.allocator;

    // Simulate 8-byte struct with i64
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "process_i64", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const result = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = Type.I32,
            .imm = hoist.immediates.Imm64.new(42),
        },
    });
    try func.dfg.attachResult(result, Type.I32);

    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{result}),
        },
    });

    try func.dfg.appendInst(entry, result);
    try func.dfg.appendInst(entry, ret);

    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("process_i64", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const compile_result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer compile_result.code.deinit();
    defer compile_result.relocs.deinit();

    try testing.expect(compile_result.code.items.len > 0);
}

// Test 2: 16-byte struct passed in two registers
test "struct args: 16-byte struct in register pair" {
    const allocator = testing.allocator;

    // Define struct type: { i64, i64 } = 16 bytes
    const struct_fields = [_]abi.StructField{
        .{ .ty = abi.Type.i64, .offset = 0 },
        .{ .ty = abi.Type.i64, .offset = 8 },
    };
    const struct_type = Type{ .@"struct" = &struct_fields };

    // Signature: fn process(s: Struct16) -> i32
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(allocator, AbiParam.new(struct_type));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "process_struct16", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const result = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = Type.I32,
            .imm = hoist.immediates.Imm64.new(99),
        },
    });
    try func.dfg.attachResult(result, Type.I32);

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

    _ = try ctx_builder.registerFunction("process_struct16", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const compile_result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer compile_result.code.deinit();
    defer compile_result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(compile_result.code.items.len > 0);

    // TODO: Verify struct passed in X0, X1 (register pair)
    // TODO: Verify X0 used for even-aligned access per AAPCS64
}

// Test 3: Large struct (> 16 bytes) passed by reference
test "struct args: large struct passed by pointer" {
    const allocator = testing.allocator;

    // Define struct type: { i64, i64, i64 } = 24 bytes (exceeds 16-byte limit)
    const struct_fields = [_]abi.StructField{
        .{ .ty = abi.Type.i64, .offset = 0 },
        .{ .ty = abi.Type.i64, .offset = 8 },
        .{ .ty = abi.Type.i64, .offset = 16 },
    };
    const struct_type = Type{ .@"struct" = &struct_fields };

    // Signature: fn process(s: Struct24) -> i32
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(allocator, AbiParam.new(struct_type));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "process_large_struct", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const result = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = Type.I32,
            .imm = hoist.immediates.Imm64.new(123),
        },
    });
    try func.dfg.attachResult(result, Type.I32);

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

    _ = try ctx_builder.registerFunction("process_large_struct", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const compile_result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer compile_result.code.deinit();
    defer compile_result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(compile_result.code.items.len > 0);

    // TODO: Verify pointer to struct passed in X0 (not struct contents)
    // TODO: Caller allocates space, passes address
}

// Test 4: HFA (Homogeneous Float Aggregate) - struct with identical float types
test "struct args: HFA with 2 floats in vector registers" {
    const allocator = testing.allocator;

    // Define HFA: { f32, f32 } = 8 bytes, should use V0, V1
    const hfa_fields = [_]abi.StructField{
        .{ .ty = abi.Type.f32, .offset = 0 },
        .{ .ty = abi.Type.f32, .offset = 4 },
    };
    const hfa_type = Type{ .@"struct" = &hfa_fields };

    // Signature: fn process(hfa: HFA) -> f32
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(allocator, AbiParam.new(hfa_type));
    try sig.returns.append(allocator, AbiParam.new(Type.F32));

    var func = try Function.init(allocator, "process_hfa", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const result = try func.dfg.makeInst(.{
        .fconst = .{
            .opcode = .fconst,
            .ty = Type.F32,
            .imm = hoist.immediates.Imm64.new(@bitCast(@as(f32, 1.5))),
        },
    });
    try func.dfg.attachResult(result, Type.F32);

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

    _ = try ctx_builder.registerFunction("process_hfa", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const compile_result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer compile_result.code.deinit();
    defer compile_result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(compile_result.code.items.len > 0);

    // TODO: Verify HFA members passed in V0, V1 (not X0)
}

// Test 5: HFA with 4 doubles (maximum HFA size)
test "struct args: HFA with 4 doubles in vector registers" {
    const allocator = testing.allocator;

    // Define HFA: { f64, f64, f64, f64 } = 32 bytes, uses V0-V3
    const hfa_fields = [_]abi.StructField{
        .{ .ty = abi.Type.f64, .offset = 0 },
        .{ .ty = abi.Type.f64, .offset = 8 },
        .{ .ty = abi.Type.f64, .offset = 16 },
        .{ .ty = abi.Type.f64, .offset = 24 },
    };
    const hfa_type = Type{ .@"struct" = &hfa_fields };

    // Signature: fn process(hfa: HFA4) -> f64
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(allocator, AbiParam.new(hfa_type));
    try sig.returns.append(allocator, AbiParam.new(Type.F64));

    var func = try Function.init(allocator, "process_hfa4", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const result = try func.dfg.makeInst(.{
        .fconst = .{
            .opcode = .fconst,
            .ty = Type.F64,
            .imm = hoist.immediates.Imm64.new(@bitCast(@as(f64, 2.718))),
        },
    });
    try func.dfg.attachResult(result, Type.F64);

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

    _ = try ctx_builder.registerFunction("process_hfa4", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const compile_result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer compile_result.code.deinit();
    defer compile_result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(compile_result.code.items.len > 0);

    // TODO: Verify HFA members passed in V0, V1, V2, V3
    // TODO: Verify 32-byte HFA handled correctly despite exceeding 16-byte general limit
}

// Test 6: Mixed struct (int + float) - not an HFA, uses general registers
test "struct args: mixed int-float struct uses general registers" {
    const allocator = testing.allocator;

    // Define mixed struct: { i32, f32 } = 8 bytes, NOT an HFA
    // Should be passed in general registers, not vector registers
    const mixed_fields = [_]abi.StructField{
        .{ .ty = abi.Type.i32, .offset = 0 },
        .{ .ty = abi.Type.f32, .offset = 4 },
    };
    const mixed_type = Type{ .@"struct" = &mixed_fields };

    // Signature: fn process(s: Mixed) -> i32
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(allocator, AbiParam.new(mixed_type));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "process_mixed", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const result = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = Type.I32,
            .imm = hoist.immediates.Imm64.new(77),
        },
    });
    try func.dfg.attachResult(result, Type.I32);

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

    _ = try ctx_builder.registerFunction("process_mixed", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const compile_result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer compile_result.code.deinit();
    defer compile_result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(compile_result.code.items.len > 0);

    // TODO: Verify mixed struct passed in X0 (general register, not V0)
    // TODO: Verify heterogeneous struct disqualifies from HFA treatment
}

// Test 7: Multiple struct arguments
test "struct args: multiple small structs" {
    const allocator = testing.allocator;

    // Define two struct types
    const struct1_fields = [_]abi.StructField{
        .{ .ty = abi.Type.i32, .offset = 0 },
        .{ .ty = abi.Type.i32, .offset = 4 },
    };
    const struct1_type = Type{ .@"struct" = &struct1_fields };

    const struct2_fields = [_]abi.StructField{
        .{ .ty = abi.Type.i64, .offset = 0 },
    };
    const struct2_type = Type{ .@"struct" = &struct2_fields };

    // Signature: fn process(s1: Struct8, s2: Struct8, n: i32) -> i32
    var sig = Signature.init(allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(allocator, AbiParam.new(struct1_type));
    try sig.params.append(allocator, AbiParam.new(struct2_type));
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "process_multiple", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Return the third argument (the i32)
    const n = func.dfg.blockParams(entry)[2];
    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{n}),
        },
    });

    try func.dfg.appendInst(entry, ret);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("process_multiple", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const compile_result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer compile_result.code.deinit();
    defer compile_result.relocs.deinit();

    // Verify: code generated successfully
    try testing.expect(compile_result.code.items.len > 0);

    // TODO: Verify s1 in X0, s2 in X1, n in X2
    // TODO: Verify register allocation respects struct boundaries
}
