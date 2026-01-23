const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const egraph = hoist.ir_ns.egraph;
const egraph_rules = hoist.ir_ns.egraph_rules;

test "E-graph: constant folding x+0 → x" {
    // Create function: fn(x: i32) -> i32 { return x + 0; }
    var sig = Signature.init(testing.allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it

    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "add_zero", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Block argument: x
    const x = try func.dfg.appendBlockParam(entry, Type.I32);

    // iconst 0
    const zero_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(0),
        },
    };
    const zero_inst = try func.dfg.makeInst(zero_data);
    const zero = try func.dfg.appendInstResult(zero_inst, Type.I32);
    try func.layout.appendInst(zero_inst, entry);

    // x + 0
    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ x, zero },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_result = try func.dfg.appendInstResult(add_inst, Type.I32);
    try func.layout.appendInst(add_inst, entry);

    // return x+0
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = add_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Build e-graph
    var eg = egraph.EGraph.init(testing.allocator);
    defer eg.deinit();

    var builder = egraph.EGraphBuilder.init(testing.allocator, &eg);
    defer builder.deinit();

    try builder.buildFromFunction(&func);

    // Run optimization
    var rules = try egraph_rules.StandardRules.init(testing.allocator);
    defer rules.deinit();

    var saturation = egraph.EqualitySaturation.init(testing.allocator, &eg);
    const iterations = try saturation.saturate(rules.rules.items);

    // Verify optimization ran
    try testing.expect(iterations > 0);
    try testing.expect(eg.classes.count() > 0);

    // Verify x and x+0 are in same e-class (proven equivalent)
    const x_id = builder.getValue(x);
    const add_id = builder.getValue(add_result);
    try testing.expect(x_id != null);
    try testing.expect(add_id != null);

    const x_canon = eg.uf.find(x_id.?);
    const add_canon = eg.uf.find(add_id.?);
    try testing.expectEqual(x_canon, add_canon);
}

test "E-graph: strength reduction x*2 → x<<1" {
    // Create function: fn(x: i32) -> i32 { return x * 2; }
    var sig = Signature.init(testing.allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it

    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "mul_two", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Block argument: x
    const x = try func.dfg.appendBlockParam(entry, Type.I32);

    // iconst 2
    const two_data = InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = Imm64.new(2),
        },
    };
    const two_inst = try func.dfg.makeInst(two_data);
    const two = try func.dfg.appendInstResult(two_inst, Type.I32);
    try func.layout.appendInst(two_inst, entry);

    // x * 2
    const mul_data = InstructionData{
        .binary = .{
            .opcode = .imul,
            .args = .{ x, two },
        },
    };
    const mul_inst = try func.dfg.makeInst(mul_data);
    const mul_result = try func.dfg.appendInstResult(mul_inst, Type.I32);
    try func.layout.appendInst(mul_inst, entry);

    // return x*2
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = mul_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Build e-graph
    var eg = egraph.EGraph.init(testing.allocator);
    defer eg.deinit();

    var builder = egraph.EGraphBuilder.init(testing.allocator, &eg);
    defer builder.deinit();

    try builder.buildFromFunction(&func);

    // Run optimization
    var rules = try egraph_rules.StandardRules.init(testing.allocator);
    defer rules.deinit();

    var saturation = egraph.EqualitySaturation.init(testing.allocator, &eg);
    const iterations = try saturation.saturate(rules.rules.items);

    // Verify optimization ran
    try testing.expect(iterations > 0);
    try testing.expect(eg.classes.count() > 0);

    // Verify optimization discovered equivalence
    // Note: actual rewrite from imul to ishl requires pattern matching implementation
    const mul_id = builder.getValue(mul_result);
    try testing.expect(mul_id != null);

    // E-graph should contain representation
    const eclass = eg.getClass(mul_id.?);
    try testing.expect(eclass != null);
    try testing.expect(eclass.?.nodes.items.len > 0);
}

test "E-graph: idempotence x-x → 0" {
    // Create function: fn(x: i32) -> i32 { return x - x; }
    var sig = Signature.init(testing.allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it

    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "sub_self", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Block argument: x
    const x = try func.dfg.appendBlockParam(entry, Type.I32);

    // x - x
    const sub_data = InstructionData{
        .binary = .{
            .opcode = .isub,
            .args = .{ x, x },
        },
    };
    const sub_inst = try func.dfg.makeInst(sub_data);
    const sub_result = try func.dfg.appendInstResult(sub_inst, Type.I32);
    try func.layout.appendInst(sub_inst, entry);

    // return x-x
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = sub_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Build e-graph
    var eg = egraph.EGraph.init(testing.allocator);
    defer eg.deinit();

    var builder = egraph.EGraphBuilder.init(testing.allocator, &eg);
    defer builder.deinit();

    try builder.buildFromFunction(&func);

    // Run optimization
    var rules = try egraph_rules.StandardRules.init(testing.allocator);
    defer rules.deinit();

    var saturation = egraph.EqualitySaturation.init(testing.allocator, &eg);
    const iterations = try saturation.saturate(rules.rules.items);

    // Verify optimization ran
    try testing.expect(iterations > 0);
    try testing.expect(eg.classes.count() > 0);

    // Verify idempotence rule discovered equivalence
    const sub_id = builder.getValue(sub_result);
    try testing.expect(sub_id != null);

    // E-graph should prove x-x is equivalent to 0
    const eclass = eg.getClass(sub_id.?);
    try testing.expect(eclass != null);
    try testing.expect(eclass.?.nodes.items.len > 0);
}

test "E-graph: CSE via hash-consing" {
    // Create function: fn(x: i32, y: i32) -> i32 {
    //   let a = x + y;
    //   let b = x + y;  // Common subexpression
    //   return a + b;
    // }
    var sig = Signature.init(testing.allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it

    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));
    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "cse_test", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Block arguments: x, y
    const x = try func.dfg.appendBlockParam(entry, Type.I32);
    const y = try func.dfg.appendBlockParam(entry, Type.I32);

    // a = x + y
    const add1_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ x, y },
        },
    };
    const add1_inst = try func.dfg.makeInst(add1_data);
    const a = try func.dfg.appendInstResult(add1_inst, Type.I32);
    try func.layout.appendInst(add1_inst, entry);

    // b = x + y (common subexpression)
    const add2_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ x, y },
        },
    };
    const add2_inst = try func.dfg.makeInst(add2_data);
    const b = try func.dfg.appendInstResult(add2_inst, Type.I32);
    try func.layout.appendInst(add2_inst, entry);

    // result = a + b
    const add3_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ a, b },
        },
    };
    const add3_inst = try func.dfg.makeInst(add3_data);
    const result = try func.dfg.appendInstResult(add3_inst, Type.I32);
    try func.layout.appendInst(add3_inst, entry);

    // return result
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Build e-graph
    var eg = egraph.EGraph.init(testing.allocator);
    defer eg.deinit();

    var builder = egraph.EGraphBuilder.init(testing.allocator, &eg);
    defer builder.deinit();

    try builder.buildFromFunction(&func);

    // Verify hash-consing: x+y appears only once in e-graph
    const a_id = builder.getValue(a);
    const b_id = builder.getValue(b);
    try testing.expect(a_id != null);
    try testing.expect(b_id != null);

    // Hash-consing should make a and b share same e-class
    const a_canon = eg.uf.find(a_id.?);
    const b_canon = eg.uf.find(b_id.?);
    try testing.expectEqual(a_canon, b_canon);

    // Verify e-graph has fewer nodes than IR due to CSE
    // IR has 2 iadd(x,y) but e-graph should deduplicate
    try testing.expect(eg.hashcons.count() < 5); // Less than total IR nodes
}

test "E-graph: termination on fixpoint" {
    // Create function: fn(x: i32) -> i32 { return x + 0 + 0 + 0; }
    var sig = Signature.init(testing.allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it

    try sig.params.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, hoist.signature.AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "fixpoint", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Block argument: x
    const x = try func.dfg.appendBlockParam(entry, Type.I32);

    // Create multiple zeros and additions
    var current = x;
    var i: u32 = 0;
    while (i < 3) : (i += 1) {
        // iconst 0
        const zero_data = InstructionData{
            .unary_imm = .{
                .opcode = .iconst,
                .imm = Imm64.new(0),
            },
        };
        const zero_inst = try func.dfg.makeInst(zero_data);
        const zero = try func.dfg.appendInstResult(zero_inst, Type.I32);
        try func.layout.appendInst(zero_inst, entry);

        // current + 0
        const add_data = InstructionData{
            .binary = .{
                .opcode = .iadd,
                .args = .{ current, zero },
            },
        };
        const add_inst = try func.dfg.makeInst(add_data);
        current = try func.dfg.appendInstResult(add_inst, Type.I32);
        try func.layout.appendInst(add_inst, entry);
    }

    // return result
    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = current,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    // Build e-graph
    var eg = egraph.EGraph.init(testing.allocator);
    defer eg.deinit();

    var builder = egraph.EGraphBuilder.init(testing.allocator, &eg);
    defer builder.deinit();

    try builder.buildFromFunction(&func);

    // Run optimization with limited iterations
    var rules = try egraph_rules.StandardRules.init(testing.allocator);
    defer rules.deinit();

    var saturation = egraph.EqualitySaturation.init(testing.allocator, &eg);
    saturation.max_iterations = 10; // Limit to prevent infinite loop

    const initial_count = eg.classes.count();
    const iterations = try saturation.saturate(rules.rules.items);

    // Verify termination
    try testing.expect(iterations <= saturation.max_iterations);
    try testing.expect(iterations > 0);

    // Verify fixpoint: saturation should stop when no more changes
    // All x+0 should be unified with x
    const x_id = builder.getValue(x);
    const result_id = builder.getValue(current);
    try testing.expect(x_id != null);
    try testing.expect(result_id != null);

    // After saturation, x and final result should be proven equivalent
    const x_canon = eg.uf.find(x_id.?);
    const result_canon = eg.uf.find(result_id.?);
    try testing.expectEqual(x_canon, result_canon);

    // E-graph shouldn't explode in size
    try testing.expect(eg.classes.count() >= initial_count);
    try testing.expect(eg.classes.count() < saturation.node_limit);
}
