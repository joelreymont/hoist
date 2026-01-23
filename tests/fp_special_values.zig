const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const Ieee32 = hoist.immediates.Ieee32;
const Ieee64 = hoist.immediates.Ieee64;
const compile_mod = @import("hoist").codegen_compile;

// Test that f32 NaN constant can be compiled.
test "FP special values: f32 NaN" {
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    const f32_type = Type.F32;
    try sig.returns.append(testing.allocator, AbiParam.new(f32_type));

    var func = try Function.init(testing.allocator, "test_f32_nan", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Create f32 NaN constant
    const nan_bits: u32 = 0x7FC00000; // Canonical quiet NaN
    const const_data = InstructionData{
        .unary_imm = .{
            .opcode = .f32const,
            .imm = hoist.immediates.Imm64.new(@as(i64, @bitCast(@as(u64, nan_bits)))),
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, f32_type);
    try func.layout.appendInst(const_inst, entry);

    // Return the NaN value
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile - should succeed
    var ctx = @import("hoist").codegen_context.Context.init(testing.allocator);
    defer ctx.deinit();
    const result = try compile_mod.compile(&ctx, &func, &.{ .arch = .aarch64, .opt_level = .none, .verify = false, .features = .{ .bits = 0 } });

    // Verify code was generated
    try testing.expect(result.code.items.len > 0);
}

// Test that f32 positive infinity constant can be compiled.
test "FP special values: f32 positive infinity" {
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    const f32_type = Type.F32;
    try sig.returns.append(testing.allocator, AbiParam.new(f32_type));

    var func = try Function.init(testing.allocator, "test_f32_inf", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Create f32 +infinity constant
    const inf_bits: u32 = 0x7F800000; // +Inf
    const const_data = InstructionData{
        .unary_imm = .{
            .opcode = .f32const,
            .imm = hoist.immediates.Imm64.new(@as(i64, @bitCast(@as(u64, inf_bits)))),
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, f32_type);
    try func.layout.appendInst(const_inst, entry);

    // Return the infinity value
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile - should succeed
    var ctx = @import("hoist").codegen_context.Context.init(testing.allocator);
    defer ctx.deinit();
    const result = try compile_mod.compile(&ctx, &func, &.{ .arch = .aarch64, .opt_level = .none, .verify = false, .features = .{ .bits = 0 } });

    // Verify code was generated
    try testing.expect(result.code.items.len > 0);
}

// Test that f32 negative infinity constant can be compiled.
test "FP special values: f32 negative infinity" {
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    const f32_type = Type.F32;
    try sig.returns.append(testing.allocator, AbiParam.new(f32_type));

    var func = try Function.init(testing.allocator, "test_f32_neg_inf", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Create f32 -infinity constant
    const neg_inf_bits: u32 = 0xFF800000; // -Inf
    const const_data = InstructionData{
        .unary_imm = .{
            .opcode = .f32const,
            .imm = hoist.immediates.Imm64.new(@as(i64, @bitCast(@as(u64, neg_inf_bits)))),
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, f32_type);
    try func.layout.appendInst(const_inst, entry);

    // Return the -infinity value
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile - should succeed
    var ctx = @import("hoist").codegen_context.Context.init(testing.allocator);
    defer ctx.deinit();
    const result = try compile_mod.compile(&ctx, &func, &.{ .arch = .aarch64, .opt_level = .none, .verify = false, .features = .{ .bits = 0 } });

    // Verify code was generated
    try testing.expect(result.code.items.len > 0);
}

// Test that f64 NaN constant can be compiled.
test "FP special values: f64 NaN" {
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    const f64_type = Type.F64;
    try sig.returns.append(testing.allocator, AbiParam.new(f64_type));

    var func = try Function.init(testing.allocator, "test_f64_nan", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Create f64 NaN constant
    const nan_bits: u64 = 0x7FF8000000000000; // Canonical quiet NaN
    const const_data = InstructionData{
        .unary_imm = .{
            .opcode = .f64const,
            .imm = hoist.immediates.Imm64.new(@as(i64, @bitCast(nan_bits))),
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, f64_type);
    try func.layout.appendInst(const_inst, entry);

    // Return the NaN value
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile - should succeed
    var ctx = @import("hoist").codegen_context.Context.init(testing.allocator);
    defer ctx.deinit();
    const result = try compile_mod.compile(&ctx, &func, &.{ .arch = .aarch64, .opt_level = .none, .verify = false, .features = .{ .bits = 0 } });

    // Verify code was generated
    try testing.expect(result.code.items.len > 0);
}

// Test that f64 positive infinity constant can be compiled.
test "FP special values: f64 positive infinity" {
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    const f64_type = Type.F64;
    try sig.returns.append(testing.allocator, AbiParam.new(f64_type));

    var func = try Function.init(testing.allocator, "test_f64_inf", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Create f64 +infinity constant
    const inf_bits: u64 = 0x7FF0000000000000; // +Inf
    const const_data = InstructionData{
        .unary_imm = .{
            .opcode = .f64const,
            .imm = hoist.immediates.Imm64.new(@as(i64, @bitCast(inf_bits))),
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, f64_type);
    try func.layout.appendInst(const_inst, entry);

    // Return the infinity value
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile - should succeed
    var ctx = @import("hoist").codegen_context.Context.init(testing.allocator);
    defer ctx.deinit();
    const result = try compile_mod.compile(&ctx, &func, &.{ .arch = .aarch64, .opt_level = .none, .verify = false, .features = .{ .bits = 0 } });

    // Verify code was generated
    try testing.expect(result.code.items.len > 0);
}

// Test that f64 negative infinity constant can be compiled.
test "FP special values: f64 negative infinity" {
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    const f64_type = Type.F64;
    try sig.returns.append(testing.allocator, AbiParam.new(f64_type));

    var func = try Function.init(testing.allocator, "test_f64_neg_inf", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Create f64 -infinity constant
    const neg_inf_bits: u64 = 0xFFF0000000000000; // -Inf
    const const_data = InstructionData{
        .unary_imm = .{
            .opcode = .f64const,
            .imm = hoist.immediates.Imm64.new(@as(i64, @bitCast(neg_inf_bits))),
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, f64_type);
    try func.layout.appendInst(const_inst, entry);

    // Return the -infinity value
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Compile - should succeed
    var ctx = @import("hoist").codegen_context.Context.init(testing.allocator);
    defer ctx.deinit();
    const result = try compile_mod.compile(&ctx, &func, &.{ .arch = .aarch64, .opt_level = .none, .verify = false, .features = .{ .bits = 0 } });

    // Verify code was generated
    try testing.expect(result.code.items.len > 0);
}

// Test that f32 zero (both +0.0 and -0.0) can be compiled.
test "FP special values: f32 signed zeros" {
    var sig = Signature.init(testing.allocator, .fast);
    defer sig.deinit();

    const f32_type = Type.F32;
    try sig.returns.append(testing.allocator, AbiParam.new(f32_type));

    // Test +0.0
    {
        var func = try Function.init(testing.allocator, "test_f32_pos_zero", sig);
        defer func.deinit();

        const entry = try func.dfg.makeBlock();
        try func.layout.appendBlock(entry);

        const const_data = InstructionData{
            .unary_imm = .{
                .opcode = .f32const,
                .imm = hoist.immediates.Imm64.new(@as(i64, @bitCast(@as(u64, 0x00000000)))), // +0.0
            },
        };
        const const_inst = try func.dfg.makeInst(const_data);
        const const_result = try func.dfg.appendInstResult(const_inst, f32_type);
        try func.layout.appendInst(const_inst, entry);

        const ret_data = InstructionData{
            .unary = .{
                .opcode = .@"return",
                .arg = const_result,
            },
        };
        const ret_inst = try func.dfg.makeInst(ret_data);
        try func.layout.appendInst(ret_inst, entry);

        var ctx = @import("hoist").codegen_context.Context.init(testing.allocator);
    defer ctx.deinit();
    const result = try compile_mod.compile(&ctx, &func, &.{ .arch = .aarch64, .opt_level = .none, .verify = false, .features = .{ .bits = 0 } });
        try testing.expect(result.code.items.len > 0);
    }

    // Test -0.0
    {
        var func = try Function.init(testing.allocator, "test_f32_neg_zero", sig);
        defer func.deinit();

        const entry = try func.dfg.makeBlock();
        try func.layout.appendBlock(entry);

        const const_data = InstructionData{
            .unary_imm = .{
                .opcode = .f32const,
                .imm = hoist.immediates.Imm64.new(@as(i64, @bitCast(@as(u64, 0x80000000)))), // -0.0
            },
        };
        const const_inst = try func.dfg.makeInst(const_data);
        const const_result = try func.dfg.appendInstResult(const_inst, f32_type);
        try func.layout.appendInst(const_inst, entry);

        const ret_data = InstructionData{
            .unary = .{
                .opcode = .@"return",
                .arg = const_result,
            },
        };
        const ret_inst = try func.dfg.makeInst(ret_data);
        try func.layout.appendInst(ret_inst, entry);

        var ctx = @import("hoist").codegen_context.Context.init(testing.allocator);
    defer ctx.deinit();
    const result = try compile_mod.compile(&ctx, &func, &.{ .arch = .aarch64, .opt_level = .none, .verify = false, .features = .{ .bits = 0 } });
        try testing.expect(result.code.items.len > 0);
    }
}
