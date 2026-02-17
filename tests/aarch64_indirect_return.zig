const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const StructField = hoist.types.StructField;
const ContextBuilder = hoist.context.ContextBuilder;
const InstructionData = hoist.instruction_data.InstructionData;
const ValueList = hoist.value_list.ValueList;
const MemFlags = hoist.memflags.MemFlags;
const ExternalName = hoist.extfunc.ExternalName;
const stackslots = hoist.stackslots;
const StackSlotKind = hoist.stack_slot_data.StackSlotKind;
const Imm64 = hoist.immediates.Imm64;

fn makeLargeStructType(func: *Function) !Type {
    const fields = [_]StructField{
        .{ .ty = Type.I64, .offset = 0 },
        .{ .ty = Type.I64, .offset = 8 },
        .{ .ty = Type.I64, .offset = 16 },
    };
    const id = try func.struct_store.intern(&fields, 24);
    return Type.fromStructId(id);
}

fn stackAddrInst(func: *Function, slot: hoist.entities.StackSlot, offset: i32, entry: hoist.entities.Block) !hoist.entities.Value {
    const addr_data = InstructionData{ .stack_load = .{
        .opcode = .stack_addr,
        .stack_slot = slot,
        .offset = offset,
    } };
    const addr_inst = try func.dfg.makeInst(addr_data);
    const addr_val = try func.dfg.appendInstResult(addr_inst, Type.I64);
    try func.layout.appendInst(addr_inst, entry);
    return addr_val;
}

fn stackLoadInst(func: *Function, slot: hoist.entities.StackSlot, offset: i32, entry: hoist.entities.Block, ty: Type) !hoist.entities.Value {
    const load_data = InstructionData{ .stack_load = .{
        .opcode = .stack_load,
        .stack_slot = slot,
        .offset = offset,
    } };
    const load_inst = try func.dfg.makeInst(load_data);
    const load_val = try func.dfg.appendInstResult(load_inst, ty);
    try func.layout.appendInst(load_inst, entry);
    return load_val;
}

// Test 1: Call function returning large struct (indirect return via X8)
test "indirect return: large struct returned via X8 pointer" {
    const allocator = testing.allocator;

    var caller_sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try caller_sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_caller", caller_sig);
    defer func.deinit();

    const struct_ty = try makeLargeStructType(&func);

    var callee_sig = Signature.init(allocator, .system_v);
    var sret_param = AbiParam.new(Type.I64);
    sret_param.purpose = .struct_return;
    try callee_sig.params.append(allocator, sret_param);
    try callee_sig.returns.append(allocator, AbiParam.new(struct_ty));

    const callee_sig_ref = try func.addSignature(callee_sig);
    const callee_name = try ExternalName.fromTestcase(allocator, "make_large_struct");
    const func_ref = try func.func_metadata.registerExternalFunc(callee_name, callee_sig_ref, .import);

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const stack_slot = try stackslots.createStackSlot(&func, StackSlotKind.explicit_slot, 24, 3);
    const sret_ptr = try stackAddrInst(&func, stack_slot, 0, entry);

    var call_args = ValueList.default();
    try func.dfg.value_lists.push(&call_args, sret_ptr);
    const call_data = InstructionData{ .call = .{
        .opcode = .call,
        .func_ref = func_ref,
        .args = call_args,
    } };
    const call_inst = try func.dfg.makeInst(call_data);
    try func.layout.appendInst(call_inst, entry);

    const load_val = try stackLoadInst(&func, stack_slot, 0, entry, Type.I64);

    const ret_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = load_val,
    } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    defer ctx.deinit();
    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test 2: Indirect call returning large struct
test "indirect return: indirect call with large struct return" {
    const allocator = testing.allocator;

    var caller_sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try caller_sig.params.append(allocator, AbiParam.new(Type.I64));
    try caller_sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "indirect_caller", caller_sig);
    defer func.deinit();

    const struct_ty = try makeLargeStructType(&func);

    var target_sig = Signature.init(allocator, .system_v);
    var sret_param = AbiParam.new(Type.I64);
    sret_param.purpose = .struct_return;
    try target_sig.params.append(allocator, sret_param);
    try target_sig.returns.append(allocator, AbiParam.new(struct_ty));
    const sig_ref = try func.addSignature(target_sig);

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const fn_ptr = try func.dfg.appendBlockParam(entry, Type.I64);

    const stack_slot = try stackslots.createStackSlot(&func, StackSlotKind.explicit_slot, 24, 3);
    const sret_ptr = try stackAddrInst(&func, stack_slot, 0, entry);

    var call_args = ValueList.default();
    try func.dfg.value_lists.push(&call_args, fn_ptr);
    try func.dfg.value_lists.push(&call_args, sret_ptr);
    const call_data = InstructionData{ .call_indirect = .{
        .opcode = .call_indirect,
        .sig_ref = sig_ref,
        .args = call_args,
    } };
    const call_inst = try func.dfg.makeInst(call_data);
    try func.layout.appendInst(call_inst, entry);

    const load_val = try stackLoadInst(&func, stack_slot, 0, entry, Type.I64);

    const ret_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = load_val,
    } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    defer ctx.deinit();
    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test 3: Function that writes to sret pointer (callee side)
test "indirect return: callee writes to X8 pointer" {
    const allocator = testing.allocator;

    const sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it

    var func = try Function.init(allocator, "make_struct", sig);
    defer func.deinit();

    const func_struct_ty = try makeLargeStructType(&func);
    var sret_param = AbiParam.new(Type.I64);
    sret_param.purpose = .struct_return;
    try func.sig.params.append(allocator, sret_param);
    try func.sig.returns.append(allocator, AbiParam.new(func_struct_ty));

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const sret_ptr = try func.dfg.appendBlockParam(entry, Type.I64);

    const val1_data = InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = Imm64.new(111),
    } };
    const val1_inst = try func.dfg.makeInst(val1_data);
    const val1 = try func.dfg.appendInstResult(val1_inst, Type.I64);
    try func.layout.appendInst(val1_inst, entry);

    const val2_data = InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = Imm64.new(222),
    } };
    const val2_inst = try func.dfg.makeInst(val2_data);
    const val2 = try func.dfg.appendInstResult(val2_inst, Type.I64);
    try func.layout.appendInst(val2_inst, entry);

    const val3_data = InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = Imm64.new(333),
    } };
    const val3_inst = try func.dfg.makeInst(val3_data);
    const val3 = try func.dfg.appendInstResult(val3_inst, Type.I64);
    try func.layout.appendInst(val3_inst, entry);

    const store1_data = InstructionData{ .store = .{
        .opcode = .store,
        .flags = MemFlags.default(),
        .args = .{ sret_ptr, val1 },
        .offset = 0,
    } };
    const store1_inst = try func.dfg.makeInst(store1_data);
    try func.layout.appendInst(store1_inst, entry);

    const store2_data = InstructionData{ .store = .{
        .opcode = .store,
        .flags = MemFlags.default(),
        .args = .{ sret_ptr, val2 },
        .offset = 8,
    } };
    const store2_inst = try func.dfg.makeInst(store2_data);
    try func.layout.appendInst(store2_inst, entry);

    const store3_data = InstructionData{ .store = .{
        .opcode = .store,
        .flags = MemFlags.default(),
        .args = .{ sret_ptr, val3 },
        .offset = 16,
    } };
    const store3_inst = try func.dfg.makeInst(store3_data);
    try func.layout.appendInst(store3_inst, entry);

    const ret_data = InstructionData{ .@"return" = .{
        .opcode = .@"return",
        .args = ValueList.default(),
    } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    defer ctx.deinit();
    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}

// Test 4: Call with both regular args and sret
test "indirect return: call with args and sret pointer" {
    const allocator = testing.allocator;

    var caller_sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it
    try caller_sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_caller_with_args", caller_sig);
    defer func.deinit();

    const struct_ty = try makeLargeStructType(&func);

    var callee_sig = Signature.init(allocator, .system_v);
    var sret_param = AbiParam.new(Type.I64);
    sret_param.purpose = .struct_return;
    try callee_sig.params.append(allocator, sret_param);
    try callee_sig.params.append(allocator, AbiParam.new(Type.I32));
    try callee_sig.returns.append(allocator, AbiParam.new(struct_ty));

    const callee_sig_ref = try func.addSignature(callee_sig);
    const callee_name = try ExternalName.fromTestcase(allocator, "make_struct_factor");
    const func_ref = try func.func_metadata.registerExternalFunc(callee_name, callee_sig_ref, .import);

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const stack_slot = try stackslots.createStackSlot(&func, StackSlotKind.explicit_slot, 24, 3);
    const sret_ptr = try stackAddrInst(&func, stack_slot, 0, entry);

    const factor_data = InstructionData{ .unary_imm = .{
        .opcode = .iconst,
        .imm = Imm64.new(2),
    } };
    const factor_inst = try func.dfg.makeInst(factor_data);
    const factor_val = try func.dfg.appendInstResult(factor_inst, Type.I32);
    try func.layout.appendInst(factor_inst, entry);

    var call_args = ValueList.default();
    try func.dfg.value_lists.push(&call_args, sret_ptr);
    try func.dfg.value_lists.push(&call_args, factor_val);
    const call_data = InstructionData{ .call = .{
        .opcode = .call,
        .func_ref = func_ref,
        .args = call_args,
    } };
    const call_inst = try func.dfg.makeInst(call_data);
    try func.layout.appendInst(call_inst, entry);

    const load_val = try stackLoadInst(&func, stack_slot, 0, entry, Type.I64);

    const ret_data = InstructionData{ .unary = .{
        .opcode = .@"return",
        .arg = load_val,
    } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    var builder = ContextBuilder.init(allocator);
    _ = try builder.targetNative();
    var ctx = builder.optLevel(.none).build();

    defer ctx.deinit();
    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    try testing.expect(code.code.items.len > 0);
}
