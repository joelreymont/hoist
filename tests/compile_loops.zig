const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Function = root.function.Function;
const Signature = root.signature.Signature;
const Type = root.types.Type;
const ContextBuilder = root.context.ContextBuilder;
const InstructionData = root.instruction_data.InstructionData;
const IntCC = root.condcodes.IntCC;

/// Test simple conditional branch: if (x > 0) return x; else return 0;
test "compile conditional branch" {
    var sig = try Signature.init(testing.allocator);
    defer sig.deinit(testing.allocator);

    try sig.params.append(testing.allocator, Type{ .int = .{ .width = 32 } });
    try sig.returns.append(testing.allocator, Type{ .int = .{ .width = 32 } });

    var func = try Function.init(testing.allocator, "cond_test", sig);
    defer func.deinit();

    // Create blocks
    const entry = func.dfg.makeBlock() catch unreachable;
    const then_block = func.dfg.makeBlock() catch unreachable;
    const else_block = func.dfg.makeBlock() catch unreachable;

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(then_block);
    try func.layout.appendBlock(else_block);

    const param = func.dfg.blockParams(entry)[0];

    // Entry: compare x > 0
    const zero_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 0,
        },
    };
    const zero_inst = try func.dfg.makeInst(zero_data);
    const zero_val = try func.dfg.appendInstResult(zero_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(zero_inst, entry);

    const cmp_data = InstructionData{
        .binary = .{
            .opcode = .icmp,
            .args = .{ param, zero_val },
        },
    };
    const cmp_inst = try func.dfg.makeInst(cmp_data);
    const cmp_result = try func.dfg.appendInstResult(cmp_inst, Type{ .int = .{ .width = 1 } });
    try func.layout.appendInst(cmp_inst, entry);

    // Branch on condition
    const brif_data = InstructionData{
        .brif = .{
            .condition = cmp_result,
            .then_dest = then_block,
            .else_dest = else_block,
        },
    };
    const brif_inst = try func.dfg.makeInst(brif_data);
    try func.layout.appendInst(brif_inst, entry);

    // Then block: return x
    const ret_then_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = param,
        },
    };
    const ret_then_inst = try func.dfg.makeInst(ret_then_data);
    try func.layout.appendInst(ret_then_inst, then_block);

    // Else block: return 0
    const ret_else_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = zero_val,
        },
    };
    const ret_else_inst = try func.dfg.makeInst(ret_else_data);
    try func.layout.appendInst(ret_else_inst, else_block);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .verify(true)
        .build();

    const code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Conditional branch compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit(testing.allocator);

    try testing.expect(code.buffer.len > 0);
}

/// Test simple loop: while (x > 0) { x = x - 1; } return x;
test "compile simple loop" {
    var sig = try Signature.init(testing.allocator);
    defer sig.deinit(testing.allocator);

    try sig.params.append(testing.allocator, Type{ .int = .{ .width = 32 } });
    try sig.returns.append(testing.allocator, Type{ .int = .{ .width = 32 } });

    var func = try Function.init(testing.allocator, "loop_test", sig);
    defer func.deinit();

    // Blocks: entry -> loop_header -> loop_body -> loop_exit
    const entry = func.dfg.makeBlock() catch unreachable;
    const loop_header = func.dfg.makeBlock() catch unreachable;
    const loop_body = func.dfg.makeBlock() catch unreachable;
    const loop_exit = func.dfg.makeBlock() catch unreachable;

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(loop_header);
    try func.layout.appendBlock(loop_body);
    try func.layout.appendBlock(loop_exit);

    const initial_param = func.dfg.blockParams(entry)[0];

    // Entry: jump to loop header
    const jump_entry_data = InstructionData{
        .jump = .{
            .destination = loop_header,
        },
    };
    const jump_entry_inst = try func.dfg.makeInst(jump_entry_data);
    try func.layout.appendInst(jump_entry_inst, entry);

    // Loop header: phi(initial, decremented), check x > 0
    // TODO: Add block parameters for phi
    const zero_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 0,
        },
    };
    const zero_inst = try func.dfg.makeInst(zero_data);
    const zero_val = try func.dfg.appendInstResult(zero_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(zero_inst, loop_header);

    const cmp_data = InstructionData{
        .binary = .{
            .opcode = .icmp,
            .args = .{ initial_param, zero_val },
        },
    };
    const cmp_inst = try func.dfg.makeInst(cmp_data);
    const cmp_result = try func.dfg.appendInstResult(cmp_inst, Type{ .int = .{ .width = 1 } });
    try func.layout.appendInst(cmp_inst, loop_header);

    const brif_data = InstructionData{
        .brif = .{
            .condition = cmp_result,
            .then_dest = loop_body,
            .else_dest = loop_exit,
        },
    };
    const brif_inst = try func.dfg.makeInst(brif_data);
    try func.layout.appendInst(brif_inst, loop_header);

    // Loop body: x = x - 1, jump back to header
    const one_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 1,
        },
    };
    const one_inst = try func.dfg.makeInst(one_data);
    const one_val = try func.dfg.appendInstResult(one_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(one_inst, loop_body);

    const sub_data = InstructionData{
        .binary = .{
            .opcode = .isub,
            .args = .{ initial_param, one_val },
        },
    };
    const sub_inst = try func.dfg.makeInst(sub_data);
    const sub_result = try func.dfg.appendInstResult(sub_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(sub_inst, loop_body);

    const jump_back_data = InstructionData{
        .jump = .{
            .destination = loop_header,
        },
    };
    const jump_back_inst = try func.dfg.makeInst(jump_back_data);
    try func.layout.appendInst(jump_back_inst, loop_body);

    // Loop exit: return current value
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = initial_param,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, loop_exit);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .verify(true)
        .build();

    const code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Loop compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit(testing.allocator);

    try testing.expect(code.buffer.len > 0);
}

/// Test switch/jump table
test "compile jump table" {
    var sig = try Signature.init(testing.allocator);
    defer sig.deinit(testing.allocator);

    try sig.params.append(testing.allocator, Type{ .int = .{ .width = 32 } });
    try sig.returns.append(testing.allocator, Type{ .int = .{ .width = 32 } });

    var func = try Function.init(testing.allocator, "switch_test", sig);
    defer func.deinit();

    const entry = func.dfg.makeBlock() catch unreachable;
    const case0 = func.dfg.makeBlock() catch unreachable;
    const case1 = func.dfg.makeBlock() catch unreachable;
    const default = func.dfg.makeBlock() catch unreachable;

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(case0);
    try func.layout.appendBlock(case1);
    try func.layout.appendBlock(default);

    const param = func.dfg.blockParams(entry)[0];

    // For now, use conditional branches instead of jump table
    // TODO: Implement br_table instruction
    const zero_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 0,
        },
    };
    const zero_inst = try func.dfg.makeInst(zero_data);
    const zero_val = try func.dfg.appendInstResult(zero_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(zero_inst, entry);

    const cmp_data = InstructionData{
        .binary = .{
            .opcode = .icmp,
            .args = .{ param, zero_val },
        },
    };
    const cmp_inst = try func.dfg.makeInst(cmp_data);
    const cmp_result = try func.dfg.appendInstResult(cmp_inst, Type{ .int = .{ .width = 1 } });
    try func.layout.appendInst(cmp_inst, entry);

    const brif_data = InstructionData{
        .brif = .{
            .condition = cmp_result,
            .then_dest = case0,
            .else_dest = default,
        },
    };
    const brif_inst = try func.dfg.makeInst(brif_data);
    try func.layout.appendInst(brif_inst, entry);

    // Case 0: return 100
    const c100_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 100,
        },
    };
    const c100_inst = try func.dfg.makeInst(c100_data);
    const c100_val = try func.dfg.appendInstResult(c100_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(c100_inst, case0);

    const ret0_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = c100_val,
        },
    };
    const ret0_inst = try func.dfg.makeInst(ret0_data);
    try func.layout.appendInst(ret0_inst, case0);

    // Default: return -1
    const cm1_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = -1,
        },
    };
    const cm1_inst = try func.dfg.makeInst(cm1_data);
    const cm1_val = try func.dfg.appendInstResult(cm1_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(cm1_inst, default);

    const ret_default_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = cm1_val,
        },
    };
    const ret_default_inst = try func.dfg.makeInst(ret_default_data);
    try func.layout.appendInst(ret_default_inst, default);

    var ctx = ContextBuilder.init(testing.allocator)
        .target(.x86_64, .linux)
        .verify(true)
        .build();

    const code = ctx.compileFunction(&func) catch |err| {
        std.debug.print("Jump table compilation failed: {}\n", .{err});
        return err;
    };
    defer code.deinit(testing.allocator);

    try testing.expect(code.buffer.len > 0);
}
