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

test "select: i128 condition merges lanes before compare" {
    var sig = Signature.init(testing.allocator, .fast);
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "select_i128_cond", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const lo = try func.dfg.appendBlockParam(entry, Type.I64);
    const hi = try func.dfg.appendBlockParam(entry, Type.I64);

    const iconcat_data = InstructionData{
        .binary = .{
            .opcode = .iconcat,
            .args = .{ lo, hi },
        },
    };
    const iconcat_inst = try func.dfg.makeInst(iconcat_data);
    const iconcat_val = try func.dfg.appendInstResult(iconcat_inst, Type.I128);
    try func.layout.appendInst(iconcat_inst, entry);

    const t_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(11),
        },
    };
    const t_inst = try func.dfg.makeInst(t_data);
    const t_val = try func.dfg.appendInstResult(t_inst, Type.I64);
    try func.layout.appendInst(t_inst, entry);

    const f_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(22),
        },
    };
    const f_inst = try func.dfg.makeInst(f_data);
    const f_val = try func.dfg.appendInstResult(f_inst, Type.I64);
    try func.layout.appendInst(f_inst, entry);

    const select_data = InstructionData{
        .ternary = .{
            .opcode = .select,
            .args = .{ iconcat_val, t_val, f_val },
        },
    };
    const select_inst = try func.dfg.makeInst(select_data);
    const select_val = try func.dfg.appendInstResult(select_inst, Type.I64);
    try func.layout.appendInst(select_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = select_val,
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
    var saw_orr = false;
    var saw_cmp64 = false;
    var saw_csel = false;
    for (lowered.vcode.insns.items) |inst| {
        switch (inst) {
            .orr_rr => saw_orr = true,
            .cmp_rr => |cmp| {
                if (cmp.size == .size64) saw_cmp64 = true;
            },
            .csel => saw_csel = true,
            else => {},
        }
    }
    try testing.expect(saw_orr);
    try testing.expect(saw_cmp64);
    try testing.expect(saw_csel);
}

test "select_spectre_guard: i128 condition merges lanes before compare" {
    var sig = Signature.init(testing.allocator, .fast);
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "select_spectre_i128_cond", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const lo = try func.dfg.appendBlockParam(entry, Type.I64);
    const hi = try func.dfg.appendBlockParam(entry, Type.I64);

    const iconcat_data = InstructionData{
        .binary = .{
            .opcode = .iconcat,
            .args = .{ lo, hi },
        },
    };
    const iconcat_inst = try func.dfg.makeInst(iconcat_data);
    const iconcat_val = try func.dfg.appendInstResult(iconcat_inst, Type.I128);
    try func.layout.appendInst(iconcat_inst, entry);

    const t_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(33),
        },
    };
    const t_inst = try func.dfg.makeInst(t_data);
    const t_val = try func.dfg.appendInstResult(t_inst, Type.I64);
    try func.layout.appendInst(t_inst, entry);

    const f_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(44),
        },
    };
    const f_inst = try func.dfg.makeInst(f_data);
    const f_val = try func.dfg.appendInstResult(f_inst, Type.I64);
    try func.layout.appendInst(f_inst, entry);

    const select_data = InstructionData{
        .ternary = .{
            .opcode = .select_spectre_guard,
            .args = .{ iconcat_val, t_val, f_val },
        },
    };
    const select_inst = try func.dfg.makeInst(select_data);
    const select_val = try func.dfg.appendInstResult(select_inst, Type.I64);
    try func.layout.appendInst(select_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = select_val,
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
    var saw_orr = false;
    var saw_cmp64 = false;
    var saw_csel = false;
    for (lowered.vcode.insns.items) |inst| {
        switch (inst) {
            .orr_rr => saw_orr = true,
            .cmp_rr => |cmp| {
                if (cmp.size == .size64) saw_cmp64 = true;
            },
            .csel => saw_csel = true,
            else => {},
        }
    }
    try testing.expect(saw_orr);
    try testing.expect(saw_cmp64);
    try testing.expect(saw_csel);
}
