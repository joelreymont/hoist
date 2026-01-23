const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const Block = hoist.entities.Block;
const Value = hoist.entities.Value;
const ContextBuilder = hoist.context.ContextBuilder;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const Verifier = hoist.verifier.Verifier;
const IntCC = hoist.condcodes.IntCC;
const FunctionBuilder = hoist.builder.FunctionBuilder;

// Test: E2E compilation of function with while loop
// Tests loop header, back edge, phi nodes via block parameters
test "E2E: while loop with phi node" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "while_loop", sig);
    defer func.deinit();
    var ir_builder = FunctionBuilder.init(&func);

    // Create blocks: entry -> loop_header -> loop_body -> loop_exit
    const entry = try func.dfg.blocks.add();
    const loop_header = try func.dfg.blocks.add();
    const loop_body = try func.dfg.blocks.add();
    const loop_exit = try func.dfg.blocks.add();

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(loop_header);
    try func.layout.appendBlock(loop_body);
    try func.layout.appendBlock(loop_exit);

    // Entry block: jump to loop header
    const param = try func.dfg.appendBlockParam(entry, Type.I32);

    try ir_builder.switchToBlock(entry);
    try ir_builder.jumpArgs(loop_header, &.{param});

    // Loop header: phi node via block parameter (loop counter)
    const loop_counter = try func.dfg.appendBlockParam(loop_header, Type.I32);

    // Compare: loop_counter > 0
    const zero_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(0),
        },
    };
    const zero_inst = try func.dfg.makeInst(zero_data);
    const zero_val = try func.dfg.appendInstResult(zero_inst, Type.I32);
    try func.layout.appendInst(zero_inst, loop_header);

    const cmp_data = InstructionData{
        .int_compare = .{
            .opcode = .icmp,
            .cond = .sgt,
            .args = .{ loop_counter, zero_val },
        },
    };
    const cmp_inst = try func.dfg.makeInst(cmp_data);
    const cmp_result = try func.dfg.appendInstResult(cmp_inst, Type.I8);
    try func.layout.appendInst(cmp_inst, loop_header);

    // Branch: if loop_counter > 0 then loop_body else loop_exit
    const brif_data = InstructionData{
        .branch = .{
            .opcode = .brif,
            .condition = cmp_result,
            .then_dest = loop_body,
            .else_dest = loop_exit,
        },
    };
    const brif_inst = try func.dfg.makeInst(brif_data);
    try func.layout.appendInst(brif_inst, loop_header);

    // Loop body: decrement counter
    const one_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(1),
        },
    };
    const one_inst = try func.dfg.makeInst(one_data);
    const one_val = try func.dfg.appendInstResult(one_inst, Type.I32);
    try func.layout.appendInst(one_inst, loop_body);

    const sub_data = InstructionData{
        .binary = .{
            .opcode = .isub,
            .args = .{ loop_counter, one_val },
        },
    };
    const sub_inst = try func.dfg.makeInst(sub_data);
    const sub_val = try func.dfg.appendInstResult(sub_inst, Type.I32);
    try func.layout.appendInst(sub_inst, loop_body);

    // Jump back to loop header (back edge)
    try ir_builder.switchToBlock(loop_body);
    try ir_builder.jumpArgs(loop_header, &.{sub_val});

    // Loop exit: return final counter value
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = loop_counter,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, loop_exit);

    // Verify block layout
    try testing.expectEqual(@as(usize, 4), func.layout.blocks.elems.items.len);

    // Verify loop header has block parameter (phi node)
    const header_params = func.dfg.blockParams(loop_header);
    try testing.expectEqual(@as(usize, 1), header_params.len);
    try testing.expectEqual(loop_counter, header_params[0]);

    // Verify SSA construction
    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();
    try verifier.verify();

    // Compile and verify code generation
    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test: E2E compilation of nested loop
// Tests multiple loop headers and nested phi nodes
test "E2E: nested loops with phi nodes" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "nested_loops", sig);
    defer func.deinit();
    var ir_builder = FunctionBuilder.init(&func);

    // Create blocks
    const entry = try func.dfg.blocks.add();
    const outer_header = try func.dfg.blocks.add();
    const inner_header = try func.dfg.blocks.add();
    const inner_body = try func.dfg.blocks.add();
    const inner_exit = try func.dfg.blocks.add();
    const outer_exit = try func.dfg.blocks.add();

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(outer_header);
    try func.layout.appendBlock(inner_header);
    try func.layout.appendBlock(inner_body);
    try func.layout.appendBlock(inner_exit);
    try func.layout.appendBlock(outer_exit);

    const param2 = try func.dfg.appendBlockParam(entry, Type.I32);

    // Entry: jump to outer loop
    try ir_builder.switchToBlock(entry);
    try ir_builder.jumpArgs(outer_header, &.{param2});

    // Outer loop header: phi node for outer counter
    const outer_counter = try func.dfg.appendBlockParam(outer_header, Type.I32);

    const zero_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(0),
        },
    };
    const zero_inst = try func.dfg.makeInst(zero_data);
    const zero_val = try func.dfg.appendInstResult(zero_inst, Type.I32);
    try func.layout.appendInst(zero_inst, outer_header);

    const outer_cmp_data = InstructionData{
        .int_compare = .{
            .opcode = .icmp,
            .cond = .sgt,
            .args = .{ outer_counter, zero_val },
        },
    };
    const outer_cmp_inst = try func.dfg.makeInst(outer_cmp_data);
    const outer_cmp_result = try func.dfg.appendInstResult(outer_cmp_inst, Type.I8);
    try func.layout.appendInst(outer_cmp_inst, outer_header);

    try ir_builder.switchToBlock(outer_header);
    try ir_builder.brifArgs(outer_cmp_result, inner_header, &.{outer_counter}, outer_exit, &.{});

    // Inner loop header: phi node for inner counter
    const inner_counter = try func.dfg.appendBlockParam(inner_header, Type.I32);

    const inner_cmp_data = InstructionData{
        .int_compare = .{
            .opcode = .icmp,
            .cond = .sgt,
            .args = .{ inner_counter, zero_val },
        },
    };
    const inner_cmp_inst = try func.dfg.makeInst(inner_cmp_data);
    const inner_cmp_result = try func.dfg.appendInstResult(inner_cmp_inst, Type.I8);
    try func.layout.appendInst(inner_cmp_inst, inner_header);

    const inner_brif_data = InstructionData{
        .branch = .{
            .opcode = .brif,
            .condition = inner_cmp_result,
            .then_dest = inner_body,
            .else_dest = inner_exit,
        },
    };
    const inner_brif_inst = try func.dfg.makeInst(inner_brif_data);
    try func.layout.appendInst(inner_brif_inst, inner_header);

    // Inner body: decrement inner counter
    const one_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(1),
        },
    };
    const one_inst = try func.dfg.makeInst(one_data);
    const one_val = try func.dfg.appendInstResult(one_inst, Type.I32);
    try func.layout.appendInst(one_inst, inner_body);

    const inner_sub_data = InstructionData{
        .binary = .{
            .opcode = .isub,
            .args = .{ inner_counter, one_val },
        },
    };
    const inner_sub_inst = try func.dfg.makeInst(inner_sub_data);
    const inner_sub_val = try func.dfg.appendInstResult(inner_sub_inst, Type.I32);
    try func.layout.appendInst(inner_sub_inst, inner_body);

    try ir_builder.switchToBlock(inner_body);
    try ir_builder.jumpArgs(inner_header, &.{inner_sub_val});

    // Inner exit: decrement outer counter and jump back
    const outer_sub_data = InstructionData{
        .binary = .{
            .opcode = .isub,
            .args = .{ outer_counter, one_val },
        },
    };
    const outer_sub_inst = try func.dfg.makeInst(outer_sub_data);
    const outer_sub_val = try func.dfg.appendInstResult(outer_sub_inst, Type.I32);
    try func.layout.appendInst(outer_sub_inst, inner_exit);

    try ir_builder.switchToBlock(inner_exit);
    try ir_builder.jumpArgs(outer_header, &.{outer_sub_val});

    // Outer exit: return final value
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = outer_counter,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, outer_exit);

    // Verify block layout
    try testing.expectEqual(@as(usize, 6), func.layout.blocks.elems.items.len);

    // Verify both loop headers have phi nodes
    try testing.expectEqual(@as(usize, 1), func.dfg.blockParams(outer_header).len);
    try testing.expectEqual(@as(usize, 1), func.dfg.blockParams(inner_header).len);

    // Verify SSA construction
    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();
    try verifier.verify();

    // Compile
    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test: E2E compilation of loop with accumulator
// Tests phi node with multiple incoming values
test "E2E: loop with accumulator phi" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "loop_accumulator", sig);
    defer func.deinit();
    var ir_builder = FunctionBuilder.init(&func);

    // sum = 0; while (n > 0) { sum = sum + n; n = n - 1; } return sum;
    const entry = try func.dfg.blocks.add();
    const loop_header = try func.dfg.blocks.add();
    const loop_body = try func.dfg.blocks.add();
    const loop_exit = try func.dfg.blocks.add();

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(loop_header);
    try func.layout.appendBlock(loop_body);
    try func.layout.appendBlock(loop_exit);

    const param3 = try func.dfg.appendBlockParam(entry, Type.I32);

    // Entry: initialize sum = 0, jump to header
    const zero_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(0),
        },
    };
    const zero_inst = try func.dfg.makeInst(zero_data);
    const sum_init = try func.dfg.appendInstResult(zero_inst, Type.I32);
    try func.layout.appendInst(zero_inst, entry);

    try ir_builder.switchToBlock(entry);
    try ir_builder.jumpArgs(loop_header, &.{ param3, sum_init });

    // Loop header: phi nodes for both n and sum
    const n = try func.dfg.appendBlockParam(loop_header, Type.I32);
    const sum = try func.dfg.appendBlockParam(loop_header, Type.I32);

    const zero_cmp_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(0),
        },
    };
    const zero_cmp_inst = try func.dfg.makeInst(zero_cmp_data);
    const zero_val = try func.dfg.appendInstResult(zero_cmp_inst, Type.I32);
    try func.layout.appendInst(zero_cmp_inst, loop_header);

    const cmp_data = InstructionData{
        .int_compare = .{
            .opcode = .icmp,
            .cond = .sgt,
            .args = .{ n, zero_val },
        },
    };
    const cmp_inst = try func.dfg.makeInst(cmp_data);
    const cmp_result = try func.dfg.appendInstResult(cmp_inst, Type.I8);
    try func.layout.appendInst(cmp_inst, loop_header);

    const brif_data = InstructionData{
        .branch = .{
            .opcode = .brif,
            .condition = cmp_result,
            .then_dest = loop_body,
            .else_dest = loop_exit,
        },
    };
    const brif_inst = try func.dfg.makeInst(brif_data);
    try func.layout.appendInst(brif_inst, loop_header);

    // Loop body: sum = sum + n, n = n - 1
    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ sum, n },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_val = try func.dfg.appendInstResult(add_inst, Type.I32);
    try func.layout.appendInst(add_inst, loop_body);

    const one_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(1),
        },
    };
    const one_inst = try func.dfg.makeInst(one_data);
    const one_val = try func.dfg.appendInstResult(one_inst, Type.I32);
    try func.layout.appendInst(one_inst, loop_body);

    const sub_data = InstructionData{
        .binary = .{
            .opcode = .isub,
            .args = .{ n, one_val },
        },
    };
    const sub_inst = try func.dfg.makeInst(sub_data);
    const sub_val = try func.dfg.appendInstResult(sub_inst, Type.I32);
    try func.layout.appendInst(sub_inst, loop_body);

    try ir_builder.switchToBlock(loop_body);
    try ir_builder.jumpArgs(loop_header, &.{ sub_val, add_val });

    // Loop exit: return sum
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = sum,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, loop_exit);

    // Verify loop header has 2 phi nodes (n and sum)
    try testing.expectEqual(@as(usize, 2), func.dfg.blockParams(loop_header).len);
    try testing.expectEqual(n, func.dfg.blockParams(loop_header)[0]);
    try testing.expectEqual(sum, func.dfg.blockParams(loop_header)[1]);

    // Verify SSA
    var verifier = Verifier.init(testing.allocator, &func);
    defer verifier.deinit();
    try verifier.verify();

    // Compile
    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.items.len > 0);
}
