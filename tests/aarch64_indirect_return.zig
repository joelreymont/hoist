const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const CallConv = hoist.signature.CallConv;
const AbiParam = hoist.signature.AbiParam;
const ArgumentPurpose = hoist.signature.ArgumentPurpose;
const Type = hoist.types.Type;
const ContextBuilder = hoist.context.ContextBuilder;
const abi = hoist.abi;
const FuncRef = hoist.entities.FuncRef;

// AAPCS64 indirect return rules:
// Per Section 6.4.2: When a function returns a struct that cannot fit in registers
// (>16 bytes or non-HFA), the caller allocates space and passes a pointer in X8.
// The callee writes the result to that address and returns (no value in X0).
//
// From caller perspective:
// 1. Allocate space for return struct on stack
// 2. Pass pointer to that space as implicit first argument in X8
// 3. After call, load result from that stack space
//
// From callee perspective:
// 1. Receive return-space pointer in X8
// 2. Write result struct to *X8
// 3. Return (no value in X0)

// Test 1: Call function returning large struct (indirect return via X8)
test "indirect return: large struct returned via X8 pointer" {
    const allocator = testing.allocator;

    // Define large struct: { i64, i64, i64 } = 24 bytes (>16 bytes)
    const struct_fields = [_]abi.StructField{
        .{ .ty = abi.Type.i64, .offset = 0 },
        .{ .ty = abi.Type.i64, .offset = 8 },
        .{ .ty = abi.Type.i64, .offset = 16 },
    };
    const large_struct_type = Type{ .@"struct" = &struct_fields };

    // Callee signature: fn make_large_struct() -> LargeStruct
    // Per AAPCS64, this implicitly becomes:
    // fn make_large_struct(sret_ptr: *LargeStruct)
    var callee_sig = Signature.init(allocator, .system_v);
    defer callee_sig.deinit();

    // Add sret parameter with .struct_return purpose
    var sret_param = AbiParam.new(Type{ .ptr = .{ .pointee = 0 } });
    sret_param.purpose = .struct_return;
    try callee_sig.params.append(allocator, sret_param);

    // Return type is the struct (even though it's indirect)
    try callee_sig.returns.append(allocator, AbiParam.new(large_struct_type));

    // Caller function: calls make_large_struct and uses result
    var caller_sig = Signature.init(allocator, .system_v);
    defer caller_sig.deinit();
    try caller_sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_caller", caller_sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Allocate stack space for return struct (24 bytes)
    const stack_slot = try func.dfg.makeInst(.{
        .stack_alloc = .{
            .opcode = .stack_alloc,
            .ty = large_struct_type,
            .size = 24,
            .align_bytes = 8,
        },
    });
    try func.dfg.attachResult(stack_slot, Type{ .ptr = .{ .pointee = 0 } });

    // Call make_large_struct with sret pointer as implicit first arg
    const callee_ref = FuncRef.new(1);
    const call = try func.dfg.makeInst(.{
        .call = .{
            .opcode = .call,
            .func_ref = callee_ref,
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{stack_slot}),
        },
    });
    // Call returns X8 (the pointer where result was written)
    try func.dfg.attachResult(call, Type{ .ptr = .{ .pointee = 0 } });

    // Load first field from result (just to use the value)
    const load = try func.dfg.makeInst(.{
        .load = .{
            .opcode = .load,
            .ty = Type.I64,
            .address = call,
            .offset = 0,
            .flags = .{},
        },
    });
    try func.dfg.attachResult(load, Type.I64);

    // Return first field
    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{load}),
        },
    });

    try func.dfg.appendInst(entry, stack_slot);
    try func.dfg.appendInst(entry, call);
    try func.dfg.appendInst(entry, load);
    try func.dfg.appendInst(entry, ret);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("test_caller", caller_sig);
    _ = try ctx_builder.registerFunction("make_large_struct", callee_sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code was generated
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify disassembly:
    // 1. Stack allocation for return struct (SUB SP, SP, #24 or similar)
    // 2. LEA of stack space into some register
    // 3. MOV X8, <that register> before BL
    // 4. BL to make_large_struct
    // 5. LDR X0, [SP, #offset] after call (load first field)
    // 6. Return with value in X0
}

// Test 2: Indirect call returning large struct
test "indirect return: indirect call with large struct return" {
    const allocator = testing.allocator;

    // Same 24-byte struct
    const struct_fields = [_]abi.StructField{
        .{ .ty = abi.Type.i64, .offset = 0 },
        .{ .ty = abi.Type.i64, .offset = 8 },
        .{ .ty = abi.Type.i64, .offset = 16 },
    };
    const large_struct_type = Type{ .@"struct" = &struct_fields };

    // Target signature: fn(*LargeStruct) (implicit sret)
    var target_sig = Signature.init(allocator, .system_v);
    defer target_sig.deinit();

    var sret_param = AbiParam.new(Type{ .ptr = .{ .pointee = 0 } });
    sret_param.purpose = .struct_return;
    try target_sig.params.append(allocator, sret_param);
    try target_sig.returns.append(allocator, AbiParam.new(large_struct_type));

    // Caller: fn caller(fn_ptr: *fn) -> i64
    var caller_sig = Signature.init(allocator, .system_v);
    defer caller_sig.deinit();
    try caller_sig.params.append(allocator, AbiParam.new(Type{ .ptr = .{ .pointee = 0 } }));
    try caller_sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "indirect_caller", caller_sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const fn_ptr = func.dfg.blockParams(entry)[0];

    // Allocate stack space for return struct
    const stack_slot = try func.dfg.makeInst(.{
        .stack_alloc = .{
            .opcode = .stack_alloc,
            .ty = large_struct_type,
            .size = 24,
            .align_bytes = 8,
        },
    });
    try func.dfg.attachResult(stack_slot, Type{ .ptr = .{ .pointee = 0 } });

    // Import target signature for indirect call
    const sig_ref = try func.dfg.importSignature(target_sig);

    // Indirect call with sret pointer
    const call = try func.dfg.makeInst(.{
        .call_indirect = .{
            .opcode = .call_indirect,
            .sig_ref = sig_ref,
            .callee = fn_ptr,
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{stack_slot}),
        },
    });
    try func.dfg.attachResult(call, Type{ .ptr = .{ .pointee = 0 } });

    // Load first field from result
    const load = try func.dfg.makeInst(.{
        .load = .{
            .opcode = .load,
            .ty = Type.I64,
            .address = call,
            .offset = 0,
            .flags = .{},
        },
    });
    try func.dfg.attachResult(load, Type.I64);

    // Return first field
    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{load}),
        },
    });

    try func.dfg.appendInst(entry, stack_slot);
    try func.dfg.appendInst(entry, call);
    try func.dfg.appendInst(entry, load);
    try func.dfg.appendInst(entry, ret);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("indirect_caller", caller_sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code was generated
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify disassembly:
    // 1. Stack allocation for return struct
    // 2. MOV X8, <stack pointer>
    // 3. BLR <fn_ptr register> (not BL - indirect call)
    // 4. LDR X0, [SP, #offset]
}

// Test 3: Function that writes to sret pointer (callee side)
test "indirect return: callee writes to X8 pointer" {
    const allocator = testing.allocator;

    // Define 24-byte struct
    const struct_fields = [_]abi.StructField{
        .{ .ty = abi.Type.i64, .offset = 0 },
        .{ .ty = abi.Type.i64, .offset = 8 },
        .{ .ty = abi.Type.i64, .offset = 16 },
    };
    const large_struct_type = Type{ .@"struct" = &struct_fields };

    // Callee signature: fn make_struct(sret_ptr: *Struct) (implicit sret parameter)
    var sig = Signature.init(allocator, .system_v);
    // Note: sig ownership transfers to func, func.deinit() frees it

    var sret_param = AbiParam.new(Type{ .ptr = .{ .pointee = 0 } });
    sret_param.purpose = .struct_return;
    try sig.params.append(allocator, sret_param);
    try sig.returns.append(allocator, AbiParam.new(large_struct_type));

    var func = try Function.init(allocator, "make_struct", sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Get sret pointer from block params (will be in X8)
    const sret_ptr = func.dfg.blockParams(entry)[0];

    // Create three constants to store
    const val1 = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = Type.I64,
            .imm = hoist.immediates.Imm64.new(111),
        },
    });
    const val2 = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = Type.I64,
            .imm = hoist.immediates.Imm64.new(222),
        },
    });
    const val3 = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = Type.I64,
            .imm = hoist.immediates.Imm64.new(333),
        },
    });
    try func.dfg.attachResult(val1, Type.I64);
    try func.dfg.attachResult(val2, Type.I64);
    try func.dfg.attachResult(val3, Type.I64);

    // Store three fields to sret pointer
    const store1 = try func.dfg.makeInst(.{
        .store = .{
            .opcode = .store,
            .address = sret_ptr,
            .value = val1,
            .offset = 0,
            .flags = .{},
        },
    });
    const store2 = try func.dfg.makeInst(.{
        .store = .{
            .opcode = .store,
            .address = sret_ptr,
            .value = val2,
            .offset = 8,
            .flags = .{},
        },
    });
    const store3 = try func.dfg.makeInst(.{
        .store = .{
            .opcode = .store,
            .address = sret_ptr,
            .value = val3,
            .offset = 16,
            .flags = .{},
        },
    });

    // Return (no return value - callee wrote to *sret_ptr)
    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{}),
        },
    });

    try func.dfg.appendInst(entry, val1);
    try func.dfg.appendInst(entry, val2);
    try func.dfg.appendInst(entry, val3);
    try func.dfg.appendInst(entry, store1);
    try func.dfg.appendInst(entry, store2);
    try func.dfg.appendInst(entry, store3);
    try func.dfg.appendInst(entry, ret);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("make_struct", sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code was generated
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify disassembly:
    // 1. X8 received as block parameter (mapped to preg)
    // 2. Three STR instructions storing to [X8, #0], [X8, #8], [X8, #16]
    // 3. RET (no value moved to X0)
}

// Test 4: Call with both regular args and sret
test "indirect return: call with args and sret pointer" {
    const allocator = testing.allocator;

    // Define 24-byte struct
    const struct_fields = [_]abi.StructField{
        .{ .ty = abi.Type.i64, .offset = 0 },
        .{ .ty = abi.Type.i64, .offset = 8 },
        .{ .ty = abi.Type.i64, .offset = 16 },
    };
    const large_struct_type = Type{ .@"struct" = &struct_fields };

    // Callee: fn make_struct(sret: *Struct, factor: i32) (sret implicit first)
    var callee_sig = Signature.init(allocator, .system_v);
    defer callee_sig.deinit();

    var sret_param = AbiParam.new(Type{ .ptr = .{ .pointee = 0 } });
    sret_param.purpose = .struct_return;
    try callee_sig.params.append(allocator, sret_param);
    try callee_sig.params.append(allocator, AbiParam.new(Type.I32)); // Regular arg
    try callee_sig.returns.append(allocator, AbiParam.new(large_struct_type));

    // Caller: fn test() -> i64
    var caller_sig = Signature.init(allocator, .system_v);
    defer caller_sig.deinit();
    try caller_sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "test_caller_with_args", caller_sig);
    defer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Allocate stack space for return struct
    const stack_slot = try func.dfg.makeInst(.{
        .stack_alloc = .{
            .opcode = .stack_alloc,
            .ty = large_struct_type,
            .size = 24,
            .align_bytes = 8,
        },
    });
    try func.dfg.attachResult(stack_slot, Type{ .ptr = .{ .pointee = 0 } });

    // Create regular argument (factor = 2)
    const factor = try func.dfg.makeInst(.{
        .iconst = .{
            .opcode = .iconst,
            .ty = Type.I32,
            .imm = hoist.immediates.Imm64.new(2),
        },
    });
    try func.dfg.attachResult(factor, Type.I32);

    // Call with sret first, then regular args
    const callee_ref = FuncRef.new(1);
    const call = try func.dfg.makeInst(.{
        .call = .{
            .opcode = .call,
            .func_ref = callee_ref,
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{ stack_slot, factor }),
        },
    });
    try func.dfg.attachResult(call, Type{ .ptr = .{ .pointee = 0 } });

    // Load first field from result
    const load = try func.dfg.makeInst(.{
        .load = .{
            .opcode = .load,
            .ty = Type.I64,
            .address = call,
            .offset = 0,
            .flags = .{},
        },
    });
    try func.dfg.attachResult(load, Type.I64);

    // Return first field
    const ret = try func.dfg.makeInst(.{
        .@"return" = .{
            .opcode = .@"return",
            .args_storage = try func.dfg.allocateValueList(&[_]hoist.value.Value{load}),
        },
    });

    try func.dfg.appendInst(entry, stack_slot);
    try func.dfg.appendInst(entry, factor);
    try func.dfg.appendInst(entry, call);
    try func.dfg.appendInst(entry, load);
    try func.dfg.appendInst(entry, ret);

    // Compile
    var ctx_builder = ContextBuilder.init(allocator);
    defer ctx_builder.deinit();

    _ = try ctx_builder.registerFunction("test_caller_with_args", caller_sig);
    _ = try ctx_builder.registerFunction("make_struct_factor", callee_sig);

    var ctx = try ctx_builder.build();
    defer ctx.deinit();

    const result = hoist.codegen.compile.compile(&ctx, &func, &ctx.target);
    defer result.code.deinit();
    defer result.relocs.deinit();

    // Verify: code was generated
    try testing.expect(result.code.items.len > 0);

    // TODO: Verify disassembly:
    // 1. MOV X8, <sret stack pointer> (sret goes in X8, NOT X0)
    // 2. MOV W0, #2 (regular arg goes in X0/W0)
    // 3. BL make_struct_factor
    // 4. LDR X0, [SP, #offset]
}
