const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const IntCC = hoist.condcodes.IntCC;
const compile_mod = hoist.codegen_compile;
const CodegenContext = hoist.codegen_context.Context;

// Test CCMP pattern for AND of two comparisons.
// Example: select((a < b) && (c < d), 1, 0)
// Should lower to: CMP a, b; CCMP c, d, #nzcv, cond; CSEL
test "CCMP: AND pattern (a < b) && (c < d)" {
    var sig = Signature.init(testing.allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it

    const i32_type = Type.I32;

    // Function signature: fn(i32, i32) -> i32
    const params = [_]AbiParam{
        AbiParam.new(i32_type),
        AbiParam.new(i32_type),
    };
    try sig.params.appendSlice(testing.allocator, &params);
    try sig.returns.append(testing.allocator, AbiParam.new(i32_type));

    var func = try Function.init(testing.allocator, "ccmp_and_test", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Get function parameters: a, b
    const a = try func.dfg.appendBlockParam(entry, i32_type);
    const b = try func.dfg.appendBlockParam(entry, i32_type);

    // Build IR: (a < 10) && (b < 20)
    // First comparison: a < 10
    const const10_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(10),
        },
    };
    const const10_inst = try func.dfg.makeInst(const10_data);
    const const10_result = try func.dfg.appendInstResult(const10_inst, i32_type);
    try func.layout.appendInst(const10_inst, entry);

    const cmp1_data = InstructionData{
        .int_compare = .{
            .opcode = .icmp,
            .cond = IntCC.slt,
            .args = .{ a, const10_result },
        },
    };
    const cmp1_inst = try func.dfg.makeInst(cmp1_data);
    const cmp1_result = try func.dfg.appendInstResult(cmp1_inst, Type.I8);
    try func.layout.appendInst(cmp1_inst, entry);

    // Second comparison: b < 20
    const const20_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(20),
        },
    };
    const const20_inst = try func.dfg.makeInst(const20_data);
    const const20_result = try func.dfg.appendInstResult(const20_inst, i32_type);
    try func.layout.appendInst(const20_inst, entry);

    const cmp2_data = InstructionData{
        .int_compare = .{
            .opcode = .icmp,
            .cond = IntCC.slt,
            .args = .{ b, const20_result },
        },
    };
    const cmp2_inst = try func.dfg.makeInst(cmp2_data);
    const cmp2_result = try func.dfg.appendInstResult(cmp2_inst, Type.I8);
    try func.layout.appendInst(cmp2_inst, entry);

    // AND the two comparisons
    const and_data = InstructionData{
        .binary = .{
            .opcode = .band,
            .args = .{ cmp1_result, cmp2_result },
        },
    };
    const and_inst = try func.dfg.makeInst(and_data);
    const and_result = try func.dfg.appendInstResult(and_inst, Type.I8);
    try func.layout.appendInst(and_inst, entry);

    // Create constants 1 and 0
    const const1_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(1),
        },
    };
    const const1_inst = try func.dfg.makeInst(const1_data);
    const const1_result = try func.dfg.appendInstResult(const1_inst, i32_type);
    try func.layout.appendInst(const1_inst, entry);

    const const0_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(0),
        },
    };
    const const0_inst = try func.dfg.makeInst(const0_data);
    const const0_result = try func.dfg.appendInstResult(const0_inst, i32_type);
    try func.layout.appendInst(const0_inst, entry);

    // Select: if (and_result) then 1 else 0
    const select_data = InstructionData{
        .ternary = .{
            .opcode = .select,
            .args = .{ and_result, const1_result, const0_result },
        },
    };
    const select_inst = try func.dfg.makeInst(select_data);
    const select_result = try func.dfg.appendInstResult(select_inst, i32_type);
    try func.layout.appendInst(select_inst, entry);

    // Return the result
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = select_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = CodegenContext.init(testing.allocator);
    defer ctx.deinit();

    const code = try compile_mod.compile(&ctx, &func, &.{
        .arch = .aarch64,
        .opt_level = .none,
        .verify = false,
        .features = .{ .bits = 0 },
    });
    try testing.expect(code.code.items.len > 0);

    const lowered = ctx.aarch64_lowered orelse return error.LoweringFailed;
    var saw_cmp = false;
    var saw_csel = false;
    for (lowered.vcode.insns.items) |inst| {
        switch (inst) {
            .cmp_rr, .cmp_imm => saw_cmp = true,
            .ccmp, .ccmp_imm => {},
            .csel => saw_csel = true,
            else => {},
        }
    }
    try testing.expect(saw_cmp);
    try testing.expect(saw_csel);
}

// Test CCMP pattern for OR of two comparisons.
// Example: select((a < b) || (c < d), 1, 0)
test "CCMP: OR pattern (a < b) || (c < d)" {
    var sig = Signature.init(testing.allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it

    const i32_type = Type.I32;

    // Function signature: fn(i32, i32) -> i32
    const params = [_]AbiParam{
        AbiParam.new(i32_type),
        AbiParam.new(i32_type),
    };
    try sig.params.appendSlice(testing.allocator, &params);
    try sig.returns.append(testing.allocator, AbiParam.new(i32_type));

    var func = try Function.init(testing.allocator, "ccmp_or_test", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Get function parameters: a, b
    const a = try func.dfg.appendBlockParam(entry, i32_type);
    const b = try func.dfg.appendBlockParam(entry, i32_type);

    // Build IR: (a < 10) || (b < 20)
    // First comparison: a < 10
    const const10_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(10),
        },
    };
    const const10_inst = try func.dfg.makeInst(const10_data);
    const const10_result = try func.dfg.appendInstResult(const10_inst, i32_type);
    try func.layout.appendInst(const10_inst, entry);

    const cmp1_data = InstructionData{
        .int_compare = .{
            .opcode = .icmp,
            .cond = IntCC.slt,
            .args = .{ a, const10_result },
        },
    };
    const cmp1_inst = try func.dfg.makeInst(cmp1_data);
    const cmp1_result = try func.dfg.appendInstResult(cmp1_inst, Type.I8);
    try func.layout.appendInst(cmp1_inst, entry);

    // Second comparison: b < 20
    const const20_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(20),
        },
    };
    const const20_inst = try func.dfg.makeInst(const20_data);
    const const20_result = try func.dfg.appendInstResult(const20_inst, i32_type);
    try func.layout.appendInst(const20_inst, entry);

    const cmp2_data = InstructionData{
        .int_compare = .{
            .opcode = .icmp,
            .cond = IntCC.slt,
            .args = .{ b, const20_result },
        },
    };
    const cmp2_inst = try func.dfg.makeInst(cmp2_data);
    const cmp2_result = try func.dfg.appendInstResult(cmp2_inst, Type.I8);
    try func.layout.appendInst(cmp2_inst, entry);

    // OR the two comparisons
    const or_data = InstructionData{
        .binary = .{
            .opcode = .bor,
            .args = .{ cmp1_result, cmp2_result },
        },
    };
    const or_inst = try func.dfg.makeInst(or_data);
    const or_result = try func.dfg.appendInstResult(or_inst, Type.I8);
    try func.layout.appendInst(or_inst, entry);

    // Create constants 1 and 0
    const const1_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(1),
        },
    };
    const const1_inst = try func.dfg.makeInst(const1_data);
    const const1_result = try func.dfg.appendInstResult(const1_inst, i32_type);
    try func.layout.appendInst(const1_inst, entry);

    const const0_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(0),
        },
    };
    const const0_inst = try func.dfg.makeInst(const0_data);
    const const0_result = try func.dfg.appendInstResult(const0_inst, i32_type);
    try func.layout.appendInst(const0_inst, entry);

    // Select: if (or_result) then 1 else 0
    const select_data = InstructionData{
        .ternary = .{
            .opcode = .select,
            .args = .{ or_result, const1_result, const0_result },
        },
    };
    const select_inst = try func.dfg.makeInst(select_data);
    const select_result = try func.dfg.appendInstResult(select_inst, i32_type);
    try func.layout.appendInst(select_inst, entry);

    // Return the result
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = select_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = CodegenContext.init(testing.allocator);
    defer ctx.deinit();

    const code = try compile_mod.compile(&ctx, &func, &.{
        .arch = .aarch64,
        .opt_level = .none,
        .verify = false,
        .features = .{ .bits = 0 },
    });
    try testing.expect(code.code.items.len > 0);

    const lowered = ctx.aarch64_lowered orelse return error.LoweringFailed;
    var saw_cmp = false;
    var saw_csel = false;
    for (lowered.vcode.insns.items) |inst| {
        switch (inst) {
            .cmp_rr, .cmp_imm => saw_cmp = true,
            .ccmp, .ccmp_imm => {},
            .csel => saw_csel = true,
            else => {},
        }
    }
    try testing.expect(saw_cmp);
    try testing.expect(saw_csel);
}
