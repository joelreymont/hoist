const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

const hoist = @import("hoist");
const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const Type = hoist.types.Type;
const Context = hoist.context.Context;
const ContextBuilder = hoist.context.ContextBuilder;
const InstructionData = hoist.instruction_data.InstructionData;
const Imm64 = hoist.immediates.Imm64;
const entities = hoist.entities;
const value_list = hoist.value_list;
const Builder = hoist.builder.Builder;
const ExternalName = hoist.external_name.ExternalName;
const types = hoist.types;
const CallConv = hoist.signature.CallConv;
const AbiParam = hoist.signature.AbiParam;

test "variadic call with fixed parameters" {
    var ctx = try ContextBuilder.init(testing.allocator);
    defer ctx.deinit();

    // Create signature for printf-like function: (I64, ...) -> I32
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();
    sig.is_varargs = true;
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64)); // format string
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    const sig_ref = try ctx.addSig(sig);

    // Create caller function that calls the varargs function
    var caller_sig = Signature.init(testing.allocator, .system_v);
    defer caller_sig.deinit();
    try caller_sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "test_varargs_call", caller_sig);
    defer func.deinit();

    var builder = try Builder.init(testing.allocator);
    defer builder.deinit();

    const entry = try builder.createBlock();
    try builder.switchToBlock(entry);
    try builder.sealBlock(entry);

    // Create arguments for the variadic call
    const fmt = builder.iconst(Type.I64, 0x1000); // format string pointer
    const arg1 = builder.iconst(Type.I32, 42);
    const arg2 = builder.iconst(Type.I32, 99);

    // Call with 3 arguments (1 fixed + 2 variadic)
    const ext_name = try ExternalName.init(testing.allocator, "printf_test");
    defer ext_name.deinit();

    var args = std.ArrayList(entities.Value).init(testing.allocator);
    defer args.deinit();
    try args.append(fmt);
    try args.append(arg1);
    try args.append(arg2);

    const result = try builder.call(sig_ref, ext_name, args.items);
    _ = try builder.return_(result);

    try builder.finalize(&func);

    // Lower to machine code (test that lowering handles varargs correctly)
    const target_triple = try hoist.target.TargetTriple.fromNative(testing.allocator);
    defer target_triple.deinit();
    const compile_ctx = try hoist.codegen.compile.compile(testing.allocator, &func, target_triple);
    defer compile_ctx.deinit();

    // Verify that lowering succeeded
    try testing.expect(compile_ctx.vcode.insts.items.len > 0);
}

test "variadic call with no extra arguments" {
    var ctx = try ContextBuilder.init(testing.allocator);
    defer ctx.deinit();

    // Varargs function with 2 fixed params
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();
    sig.is_varargs = true;
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, AbiParam.new(Type.I32));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    const sig_ref = try ctx.addSig(sig);

    var caller_sig = Signature.init(testing.allocator, .system_v);
    defer caller_sig.deinit();
    try caller_sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "test_varargs_no_extra", caller_sig);
    defer func.deinit();

    var builder = try Builder.init(testing.allocator);
    defer builder.deinit();

    const entry = try builder.createBlock();
    try builder.switchToBlock(entry);
    try builder.sealBlock(entry);

    // Call with only fixed arguments (no variadic args)
    const fmt = builder.iconst(Type.I64, 0x1000);
    const arg1 = builder.iconst(Type.I32, 42);

    const ext_name = try ExternalName.init(testing.allocator, "varargs_fn");
    defer ext_name.deinit();

    var args = std.ArrayList(entities.Value).init(testing.allocator);
    defer args.deinit();
    try args.append(fmt);
    try args.append(arg1);

    const result = try builder.call(sig_ref, ext_name, args.items);
    _ = try builder.return_(result);

    try builder.finalize(&func);

    const target_triple = try hoist.target.TargetTriple.fromNative(testing.allocator);
    defer target_triple.deinit();
    const compile_ctx = try hoist.codegen.compile.compile(testing.allocator, &func, target_triple);
    defer compile_ctx.deinit();

    try testing.expect(compile_ctx.vcode.insts.items.len > 0);
}

test "variadic indirect call" {
    var ctx = try ContextBuilder.init(testing.allocator);
    defer ctx.deinit();

    // Varargs signature
    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();
    sig.is_varargs = true;
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    const sig_ref = try ctx.addSig(sig);

    var caller_sig = Signature.init(testing.allocator, .system_v);
    defer caller_sig.deinit();
    try caller_sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "test_varargs_indirect", caller_sig);
    defer func.deinit();

    var builder = try Builder.init(testing.allocator);
    defer builder.deinit();

    const entry = try builder.createBlock();
    try builder.switchToBlock(entry);
    try builder.sealBlock(entry);

    // Function pointer
    const fn_ptr = builder.iconst(Type.I64, 0x2000);
    const fmt = builder.iconst(Type.I64, 0x1000);
    const arg1 = builder.iconst(Type.I32, 42);
    const arg2 = builder.iconst(Type.F64, 3.14);

    var args = std.ArrayList(entities.Value).init(testing.allocator);
    defer args.deinit();
    try args.append(fmt);
    try args.append(arg1);
    try args.append(arg2);

    const result = try builder.callIndirect(sig_ref, fn_ptr, args.items);
    _ = try builder.return_(result);

    try builder.finalize(&func);

    const target_triple = try hoist.target.TargetTriple.fromNative(testing.allocator);
    defer target_triple.deinit();
    const compile_ctx = try hoist.codegen.compile.compile(testing.allocator, &func, target_triple);
    defer compile_ctx.deinit();

    try testing.expect(compile_ctx.vcode.insts.items.len > 0);
}

test "variadic call type validation" {
    var ctx = try ContextBuilder.init(testing.allocator);
    defer ctx.deinit();

    var sig = Signature.init(testing.allocator, .system_v);
    defer sig.deinit();
    sig.is_varargs = true;
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    const sig_ref = try ctx.addSig(sig);

    var caller_sig = Signature.init(testing.allocator, .system_v);
    defer caller_sig.deinit();
    try caller_sig.returns.append(testing.allocator, AbiParam.new(Type.I32));

    var func = try Function.init(testing.allocator, "test_varargs_validation", caller_sig);
    defer func.deinit();

    var builder = try Builder.init(testing.allocator);
    defer builder.deinit();

    const entry = try builder.createBlock();
    try builder.switchToBlock(entry);
    try builder.sealBlock(entry);

    // Fixed arg has correct type
    const fmt = builder.iconst(Type.I64, 0x1000);
    // Variadic args can be any type
    const arg1 = builder.iconst(Type.I32, 1);
    const arg2 = builder.iconst(Type.F32, 2.0);
    const arg3 = builder.iconst(Type.I64, 3);

    const ext_name = try ExternalName.init(testing.allocator, "varargs_fn");
    defer ext_name.deinit();

    var args = std.ArrayList(entities.Value).init(testing.allocator);
    defer args.deinit();
    try args.append(fmt);
    try args.append(arg1);
    try args.append(arg2);
    try args.append(arg3);

    const result = try builder.call(sig_ref, ext_name, args.items);
    _ = try builder.return_(result);

    try builder.finalize(&func);

    const target_triple = try hoist.target.TargetTriple.fromNative(testing.allocator);
    defer target_triple.deinit();
    const compile_ctx = try hoist.codegen.compile.compile(testing.allocator, &func, target_triple);
    defer compile_ctx.deinit();

    try testing.expect(compile_ctx.vcode.insts.items.len > 0);
}
