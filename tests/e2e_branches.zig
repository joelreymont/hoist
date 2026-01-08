const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const CallConv = hoist.signature.CallConv;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const Block = hoist.entities.Block;
const JumpTable = hoist.entities.JumpTable;
const ContextBuilder = hoist.context.ContextBuilder;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const Verifier = hoist.verifier.Verifier;
const CompileContext = hoist.compile.CompileContext;
const IntCC = hoist.condcodes.IntCC;
const JumpTableData = hoist.jump_table_data.JumpTableData;
const BlockCall = hoist.block_call.BlockCall;
const ValueListPool = hoist.value_list.ValueListPool;

// Test function with conditional branches: if (x > 0) return x; else return 0;
test "E2E: conditional branch if-then-else" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "cond_branch", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    const then_block = try func.dfg.makeBlock();
    const else_block = try func.dfg.makeBlock();

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(then_block);
    try func.layout.appendBlock(else_block);

    const param = try func.dfg.appendBlockParam(entry, Type.I32);

    const zero_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(0),
        },
    };
    const zero_inst = try func.dfg.makeInst(zero_data);
    const zero_val = try func.dfg.appendInstResult(zero_inst, Type.I32);
    try func.layout.appendInst(zero_inst, entry);

    const cmp_data = InstructionData{
        .int_compare = .{
            .opcode = .icmp,
            .cond = .sgt,
            .args = .{ param, zero_val },
        },
    };
    const cmp_inst = try func.dfg.makeInst(cmp_data);
    const cmp_result = try func.dfg.appendInstResult(cmp_inst, Type.I8);
    try func.layout.appendInst(cmp_inst, entry);

    const brif_data = InstructionData{
        .branch = .{
            .opcode = .brif,
            .condition = cmp_result,
            .then_dest = then_block,
            .else_dest = else_block,
        },
    };
    const brif_inst = try func.dfg.makeInst(brif_data);
    try func.layout.appendInst(brif_inst, entry);

    const ret_then_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = param,
        },
    };
    const ret_then_inst = try func.dfg.makeInst(ret_then_data);
    try func.layout.appendInst(ret_then_inst, then_block);

    const ret_else_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = zero_val,
        },
    };
    const ret_else_inst = try func.dfg.makeInst(ret_else_data);
    try func.layout.appendInst(ret_else_inst, else_block);

    try testing.expectEqual(@as(usize, 3), func.layout.blocks.elems.items.len);

    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();
    try verifier.verify();

    var builder = ContextBuilder.init(testing.allocator);
    var ctx = builder.targetNative()
        .optLevel(.none)
        .build();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test br_table: switch (x) { case 0: return 100; case 1: return 200; case 2: return 300; default: return 0; }
test "E2E: br_table switch statement" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "switch_func", sig);
    defer func.deinit();

    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit();

    const entry = try func.dfg.makeBlock();
    const case0_block = try func.dfg.makeBlock();
    const case1_block = try func.dfg.makeBlock();
    const case2_block = try func.dfg.makeBlock();
    const default_block = try func.dfg.makeBlock();

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(case0_block);
    try func.layout.appendBlock(case1_block);
    try func.layout.appendBlock(case2_block);
    try func.layout.appendBlock(default_block);

    const param = try func.dfg.appendBlockParam(entry, Type.I32);

    // Create jump table
    const default_call = try BlockCall.new(default_block, &.{}, &pool);
    const case_calls = [_]BlockCall{
        try BlockCall.new(case0_block, &.{}, &pool),
        try BlockCall.new(case1_block, &.{}, &pool),
        try BlockCall.new(case2_block, &.{}, &pool),
    };
    const jt_data = try JumpTableData.new(testing.allocator, default_call, &case_calls);
    const jt = try func.jump_tables.push(jt_data);

    // br_table param, jt
    const br_table_data = InstructionData{
        .branch_table = .{
            .opcode = .br_table,
            .arg = param,
            .destination = jt,
        },
    };
    const br_table_inst = try func.dfg.makeInst(br_table_data);
    try func.layout.appendInst(br_table_inst, entry);

    // case 0: return 100
    const const100_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(100),
        },
    };
    const const100_inst = try func.dfg.makeInst(const100_data);
    const const100_val = try func.dfg.appendInstResult(const100_inst, Type.I32);
    try func.layout.appendInst(const100_inst, case0_block);

    const ret0_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const100_val,
        },
    };
    const ret0_inst = try func.dfg.makeInst(ret0_data);
    try func.layout.appendInst(ret0_inst, case0_block);

    // case 1: return 200
    const const200_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(200),
        },
    };
    const const200_inst = try func.dfg.makeInst(const200_data);
    const const200_val = try func.dfg.appendInstResult(const200_inst, Type.I32);
    try func.layout.appendInst(const200_inst, case1_block);

    const ret1_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const200_val,
        },
    };
    const ret1_inst = try func.dfg.makeInst(ret1_data);
    try func.layout.appendInst(ret1_inst, case1_block);

    // case 2: return 300
    const const300_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(300),
        },
    };
    const const300_inst = try func.dfg.makeInst(const300_data);
    const const300_val = try func.dfg.appendInstResult(const300_inst, Type.I32);
    try func.layout.appendInst(const300_inst, case2_block);

    const ret2_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const300_val,
        },
    };
    const ret2_inst = try func.dfg.makeInst(ret2_data);
    try func.layout.appendInst(ret2_inst, case2_block);

    // default: return 0
    const const0_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(0),
        },
    };
    const const0_inst = try func.dfg.makeInst(const0_data);
    const const0_val = try func.dfg.appendInstResult(const0_inst, Type.I32);
    try func.layout.appendInst(const0_inst, default_block);

    const ret_default_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = const0_val,
        },
    };
    const ret_default_inst = try func.dfg.makeInst(ret_default_data);
    try func.layout.appendInst(ret_default_inst, default_block);

    try testing.expectEqual(@as(usize, 5), func.layout.blocks.elems.items.len);

    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();
    try verifier.verify();

    var builder = ContextBuilder.init(testing.allocator);
    var ctx = builder.targetNative()
        .optLevel(.none)
        .build();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.items.len > 0);
}

test "E2E: brz branch if zero" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    // Function signature: fn(i64) -> i64
    try sig.params.append(testing.allocator, AbiParam.new(Type.int(64).?));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.int(64).?));

    var func = try Function.init(testing.allocator, "test_brz", sig);
    defer func.deinit();

    const entry_block = try func.dfg.createBlock();
    const zero_block = try func.dfg.createBlock();
    const nonzero_block = try func.dfg.createBlock();

    func.layout.appendBlock(entry_block);
    func.layout.appendBlock(zero_block);
    func.layout.appendBlock(nonzero_block);

    const param = func.dfg.blockParams(entry_block)[0];

    // entry: brz param, zero_block
    const brz_inst = try func.dfg.createInst(.{
        .branch_z = .{
            .opcode = .brz,
            .condition = param,
            .destination = zero_block,
        },
    }, Type.void());
    func.layout.appendInst(entry_block, brz_inst);

    // Also add fallthrough jump to nonzero_block
    const jump_inst = try func.dfg.createInst(.{
        .jump = .{
            .opcode = .jump,
            .destination = nonzero_block,
        },
    }, Type.void());
    func.layout.appendInst(entry_block, jump_inst);

    // zero_block: return 0
    const zero_val = try func.dfg.makeIconst(Type.int(64), 0);
    const ret0_inst = try func.dfg.createInst(.{
        .unary = .{
            .opcode = .@"return",
            .arg = zero_val,
        },
    }, Type.void());
    func.layout.appendInst(zero_block, ret0_inst);

    // nonzero_block: return 1
    const one_val = try func.dfg.makeIconst(Type.int(64), 1);
    const ret1_inst = try func.dfg.createInst(.{
        .unary = .{
            .opcode = .@"return",
            .arg = one_val,
        },
    }, Type.void());
    func.layout.appendInst(nonzero_block, ret1_inst);

    var ctx = CompileContext
        .forTarget(.aarch64)
        .optLevel(.none)
        .build();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.items.len > 0);
}
