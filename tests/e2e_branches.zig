const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const CallConv = hoist.signature.CallConv;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const Block = hoist.entities.Block;
const ContextBuilder = hoist.context.ContextBuilder;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const Verifier = hoist.verifier.Verifier;
const IntCC = hoist.condcodes.IntCC;

// Test function with conditional branches: if (x > 0) return x; else return 0;
test "E2E: conditional branch if-then-else" {
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();

    try sig.params.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "cond_branch", sig);
    defer func.deinit();

    const entry = Block.new(0);
    const then_block = Block.new(1);
    const else_block = Block.new(2);

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(then_block);
    try func.layout.appendBlock(else_block);

    const param = func.dfg.blockParams(entry)[0];

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
    var ctx = builder.target(.x86_64, .linux)
        .optLevel(.none)
        .build();

    const code = try ctx.compileFunction(&func);
    var code_copy = code;
    defer code_copy.deinit();

    try testing.expect(code.code.items.len > 0);
}
