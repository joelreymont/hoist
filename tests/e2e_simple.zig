const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const Type = hoist.types.Type;
const Context = hoist.context.Context;
const ContextBuilder = hoist.context.ContextBuilder;
const InstructionData = hoist.instruction_data.InstructionData;
const Verifier = hoist.verifier.Verifier;
const CallConv = hoist.abi.CallConv;

test "E2E: return constant i32" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "const_42", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const const_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 42,
        },
    };
    const const_inst = try func.dfg.makeInst(const_data);
    const const_result = try func.dfg.appendInstResult(const_inst, Type.I32);
    try func.layout.appendInst(const_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .optLevel(.none)
        .build();

    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();
    try verifier.verify();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.len > 0);
}

test "E2E: simple arithmetic i32 add" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));
    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "add_i32", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const param0 = func.dfg.blockParams(entry)[0];
    const param1 = func.dfg.blockParams(entry)[1];

    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ param0, param1 },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_result = try func.dfg.appendInstResult(add_inst, Type.I32);
    try func.layout.appendInst(add_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = add_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .optLevel(.none)
        .build();

    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();
    try verifier.verify();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.len > 0);
}

test "E2E: arithmetic i64 multiply" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "mul_i64", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const param0 = func.dfg.blockParams(entry)[0];
    const param1 = func.dfg.blockParams(entry)[1];

    const mul_data = InstructionData{
        .binary = .{
            .opcode = .imul,
            .args = .{ param0, param1 },
        },
    };
    const mul_inst = try func.dfg.makeInst(mul_data);
    const mul_result = try func.dfg.appendInstResult(mul_inst, Type.I64);
    try func.layout.appendInst(mul_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = mul_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .optLevel(.none)
        .build();

    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();
    try verifier.verify();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.len > 0);
}

test "E2E: constant computation with optimization" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "const_fold", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const const1_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 10,
        },
    };
    const const1_inst = try func.dfg.makeInst(const1_data);
    const const1_result = try func.dfg.appendInstResult(const1_inst, Type.I32);
    try func.layout.appendInst(const1_inst, entry);

    const const2_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 32,
        },
    };
    const const2_inst = try func.dfg.makeInst(const2_data);
    const const2_result = try func.dfg.appendInstResult(const2_inst, Type.I32);
    try func.layout.appendInst(const2_inst, entry);

    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ const1_result, const2_result },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_result = try func.dfg.appendInstResult(add_inst, Type.I32);
    try func.layout.appendInst(add_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = add_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .optLevel(.speed)
        .optimize(true)
        .build();

    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();
    try verifier.verify();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.len > 0);
}

test "E2E: aarch64 simple add" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "add_aarch64", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const param0 = func.dfg.blockParams(entry)[0];
    const param1 = func.dfg.blockParams(entry)[1];

    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ param0, param1 },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_result = try func.dfg.appendInstResult(add_inst, Type.I64);
    try func.layout.appendInst(add_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = add_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.aarch64, .linux)
        .optLevel(.none)
        .callConv(.aapcs64)
        .build();

    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();
    try verifier.verify();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.len > 0);
}

test "E2E: verify compilation stages" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "identity", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const param0 = func.dfg.blockParams(entry)[0];

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = param0,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    try testing.expectEqual(@as(usize, 1), func.dfg.insts.elems.items.len);
    try testing.expectEqual(@as(usize, 1), func.layout.blocks.elems.items.len);

    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();
    try verifier.verify();

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .optLevel(.none)
        .verification(true)
        .build();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.len > 0);
    try testing.expectEqual(@as(u32, 0), code.stack_frame_size);
}
