const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const ContextBuilder = hoist.context.ContextBuilder;

// Test TLS Local-Exec model with small offset (<4096 bytes).
// Local-Exec: MRS x0, TPIDR_EL0; ADD x0, x0, #offset
test "TLS: Local-Exec model small offset" {
    var sig = Signature.init(testing.allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it

    const i64_type = Type.I64;
    try sig.returns.append(testing.allocator, AbiParam.new(i64_type));

    var func = try Function.init(testing.allocator, "tls_le_small", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const tls_data = InstructionData{
        .unary_imm = .{
            .opcode = .tls_value,
            .imm = Imm64.new(256),
        },
    };
    const tls_inst = try func.dfg.makeInst(tls_data);
    const tls_result = try func.dfg.appendInstResult(tls_inst, i64_type);
    try func.layout.appendInst(tls_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = tls_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();
    var result = try ctx.compileFunction(&func);
    defer result.deinit();

    try testing.expect(result.code.items.len > 0);
}

test "TLS: Local-Exec model large offset" {
    var sig = Signature.init(testing.allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it

    const i64_type = Type.I64;
    try sig.returns.append(testing.allocator, AbiParam.new(i64_type));

    var func = try Function.init(testing.allocator, "tls_le_large", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const tls_data = InstructionData{
        .unary_imm = .{
            .opcode = .tls_value,
            .imm = Imm64.new(0x10000),
        },
    };
    const tls_inst = try func.dfg.makeInst(tls_data);
    const tls_result = try func.dfg.appendInstResult(tls_inst, i64_type);
    try func.layout.appendInst(tls_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = tls_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();
    var result = try ctx.compileFunction(&func);
    defer result.deinit();

    try testing.expect(result.code.items.len > 0);
}

test "TLS: Local-Exec model zero offset" {
    var sig = Signature.init(testing.allocator, .fast);
    // Note: sig ownership transfers to func, func.deinit() frees it

    const i64_type = Type.I64;
    try sig.returns.append(testing.allocator, AbiParam.new(i64_type));

    var func = try Function.init(testing.allocator, "tls_le_zero", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const tls_data = InstructionData{
        .unary_imm = .{
            .opcode = .tls_value,
            .imm = Imm64.new(0),
        },
    };
    const tls_inst = try func.dfg.makeInst(tls_data);
    const tls_result = try func.dfg.appendInstResult(tls_inst, i64_type);
    try func.layout.appendInst(tls_inst, entry);

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = tls_result,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(testing.allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();
    var result = try ctx.compileFunction(&func);
    defer result.deinit();

    try testing.expect(result.code.items.len > 0);
}
