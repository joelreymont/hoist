const std = @import("std");
const testing = std.testing;
const hoist = @import("hoist");

const Riscv64ISA = hoist.riscv64_isa.Riscv64ISA;
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;

test "riscv64: iadd i32" {
    var sig = Signature.init(testing.allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it

    try sig.params.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.params.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "add_i32", sig);
    defer func.deinit();

    const entry = try func.dfg.blocks.add();
    try func.layout.appendBlock(entry);

    const x = try func.dfg.appendBlockParam(entry, Type.I32);
    const y = try func.dfg.appendBlockParam(entry, Type.I32);

    const add_data = InstructionData{ .binary = .{ .opcode = .iadd, .args = .{ x, y } } };
    const add_inst = try func.dfg.makeInst(add_data);
    const sum = try func.dfg.appendInstResult(add_inst, Type.I32);
    try func.layout.appendInst(add_inst, entry);

    const ret_data = InstructionData{ .unary = .{ .opcode = .@"return", .arg = sum } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    const ctx = hoist.compile.CompileCtx.init(testing.allocator, "riscv64");
    var code = try Riscv64ISA.compileFunction(ctx, &func);
    defer code.deinit();

    try testing.expect(code.code.len > 0);
}

test "riscv64: isub i64" {
    var sig = Signature.init(testing.allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it

    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "sub_i64", sig);
    defer func.deinit();

    const entry = try func.dfg.blocks.add();
    try func.layout.appendBlock(entry);

    const x = try func.dfg.appendBlockParam(entry, Type.I64);
    const y = try func.dfg.appendBlockParam(entry, Type.I64);

    const sub_data = InstructionData{ .binary = .{ .opcode = .isub, .args = .{ x, y } } };
    const sub_inst = try func.dfg.makeInst(sub_data);
    const diff = try func.dfg.appendInstResult(sub_inst, Type.I64);
    try func.layout.appendInst(sub_inst, entry);

    const ret_data = InstructionData{ .unary = .{ .opcode = .@"return", .arg = diff } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    const ctx = hoist.compile.CompileCtx.init(testing.allocator, "riscv64");
    var code = try Riscv64ISA.compileFunction(ctx, &func);
    defer code.deinit();

    try testing.expect(code.code.len > 0);
}

test "riscv64: band i64" {
    var sig = Signature.init(testing.allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it

    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "and_i64", sig);
    defer func.deinit();

    const entry = try func.dfg.blocks.add();
    try func.layout.appendBlock(entry);

    const x = try func.dfg.appendBlockParam(entry, Type.I64);
    const y = try func.dfg.appendBlockParam(entry, Type.I64);

    const and_data = InstructionData{ .binary = .{ .opcode = .band, .args = .{ x, y } } };
    const and_inst = try func.dfg.makeInst(and_data);
    const result = try func.dfg.appendInstResult(and_inst, Type.I64);
    try func.layout.appendInst(and_inst, entry);

    const ret_data = InstructionData{ .unary = .{ .opcode = .@"return", .arg = result } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    const ctx = hoist.compile.CompileCtx.init(testing.allocator, "riscv64");
    var code = try Riscv64ISA.compileFunction(ctx, &func);
    defer code.deinit();

    try testing.expect(code.code.len > 0);
}
