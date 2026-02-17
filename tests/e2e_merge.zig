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
const FunctionBuilder = hoist.builder.FunctionBuilder;
const IntCC = hoist.condcodes.IntCC;
const JitMem = hoist.jit.memory.Mem;

// Test: simplest possible merge — if x==0 then 42 else 99
// One param, two branches, one merge block with block param, return.
test "E2E: simplest merge with block param" {
    var sig = Signature.init(testing.allocator, .system_v);
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "simple_merge", sig);
    defer func.deinit();
    var b = try FunctionBuilder.init(testing.allocator, &func);

    const entry = try func.dfg.blocks.add();
    const then_blk = try func.dfg.blocks.add();
    const else_blk = try func.dfg.blocks.add();
    const merge_blk = try func.dfg.blocks.add();

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(then_blk);
    try func.layout.appendBlock(else_blk);
    try func.layout.appendBlock(merge_blk);

    // Entry: branch on x == 0
    const x = try func.dfg.appendBlockParam(entry, Type.I64);
    b.switchToBlock(entry);
    const zero = try b.iconst(Type.I64, 0);
    const cmp = try b.icmp(Type.I64, IntCC.eq, x, zero);
    try b.brif(cmp, then_blk, else_blk);

    // Then: jump to merge with 42
    b.switchToBlock(then_blk);
    const val42 = try b.iconst(Type.I64, 42);
    try b.jumpArgs(merge_blk, &.{val42});

    // Else: jump to merge with 99
    b.switchToBlock(else_blk);
    const val99 = try b.iconst(Type.I64, 99);
    try b.jumpArgs(merge_blk, &.{val99});

    // Merge: return the block param
    const merge_param = try func.dfg.appendBlockParam(merge_blk, Type.I64);
    b.switchToBlock(merge_blk);
    try b.retValues(&.{merge_param});

    // Compile
    var ctx_builder = ContextBuilder.init(testing.allocator);
    var ctx = ctx_builder.optLevel(.none).callConv(.system_v).verification(false).build();
    defer ctx.deinit();
    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Copy to executable memory
    const mem = try testing.allocator.create(JitMem);
    mem.* = try JitMem.init(testing.allocator, code.code.items.len);
    defer {
        mem.deinit();
        testing.allocator.destroy(mem);
    }
    const buf = try mem.alloc(code.code.items.len, 16);
    try mem.writeExec(buf, code.code.items);
    try mem.setExec(true);

    const f: *const fn (i64) callconv(.c) i64 = @ptrCast(@alignCast(buf.ptr));
    const r1 = f(0); // x==0 → 42
    const r2 = f(1); // x!=0 → 99

    try testing.expectEqual(@as(i64, 42), r1);
    try testing.expectEqual(@as(i64, 99), r2);
}

// Test: TCO-like pattern — loop header with block params, tail "call" as jump back
// Pattern: factorial(n) → header(n, acc) → if n==0 return acc else jump header(n-1, acc*n)
test "E2E: TCO loop with block params" {
    var sig = Signature.init(testing.allocator, .system_v);
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "tco_factorial", sig);
    defer func.deinit();
    var b = try FunctionBuilder.init(testing.allocator, &func);

    const entry = try func.dfg.blocks.add();
    const header = try func.dfg.blocks.add();
    const body = try func.dfg.blocks.add();
    const exit = try func.dfg.blocks.add();

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(header);
    try func.layout.appendBlock(body);
    try func.layout.appendBlock(exit);

    // Entry: jump to header(n, 1)
    const param_n = try func.dfg.appendBlockParam(entry, Type.I64);
    b.switchToBlock(entry);
    const one = try b.iconst(Type.I64, 1);
    try b.jumpArgs(header, &.{ param_n, one });

    // Header: phi(n, acc). If n==0 → exit(acc) else → body
    const phi_n = try func.dfg.appendBlockParam(header, Type.I64);
    const phi_acc = try func.dfg.appendBlockParam(header, Type.I64);
    b.switchToBlock(header);
    const zero = try b.iconst(Type.I64, 0);
    const cmp = try b.icmp(Type.I64, IntCC.eq, phi_n, zero);
    try b.brif(cmp, exit, body);

    // Body: jump header(n-1, acc*n)
    b.switchToBlock(body);
    const n_minus_1 = try b.isub(Type.I64, phi_n, one);
    const acc_times_n = try b.imul(Type.I64, phi_acc, phi_n);
    try b.jumpArgs(header, &.{ n_minus_1, acc_times_n });

    // Exit: return acc
    b.switchToBlock(exit);
    try b.retValues(&.{phi_acc});

    // Compile
    var ctx_builder = ContextBuilder.init(testing.allocator);
    var ctx = ctx_builder.optLevel(.none).callConv(.system_v).verification(false).build();
    defer ctx.deinit();
    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    // Copy to executable memory
    const mem = try testing.allocator.create(JitMem);
    mem.* = try JitMem.init(testing.allocator, code.code.items.len);
    defer {
        mem.deinit();
        testing.allocator.destroy(mem);
    }
    const buf = try mem.alloc(code.code.items.len, 16);
    try mem.writeExec(buf, code.code.items);
    try mem.setExec(true);

    const f: *const fn (i64) callconv(.c) i64 = @ptrCast(@alignCast(buf.ptr));
    try testing.expectEqual(@as(i64, 1), f(0)); // 0! = 1
    try testing.expectEqual(@as(i64, 1), f(1)); // 1! = 1
    try testing.expectEqual(@as(i64, 2), f(2)); // 2! = 2
    try testing.expectEqual(@as(i64, 6), f(3)); // 3! = 6
    try testing.expectEqual(@as(i64, 120), f(5)); // 5! = 120
    try testing.expectEqual(@as(i64, 3628800), f(10)); // 10! = 3628800
}

// Test: TCO with 3 params and nested ifs — matches safe-p pattern
// if placed==0 then return 1 else (check condition, recurse or return 0)
test "E2E: TCO 3-param with nested if" {
    var sig = Signature.init(testing.allocator, .system_v);
    // 3 params: a, b, c
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.params.append(testing.allocator, AbiParam.new(Type.I64));
    try sig.returns.append(testing.allocator, AbiParam.new(Type.I64));

    var func = try Function.init(testing.allocator, "tco3", sig);
    defer func.deinit();
    var b = try FunctionBuilder.init(testing.allocator, &func);

    const entry = try func.dfg.blocks.add();
    const header = try func.dfg.blocks.add();
    const check = try func.dfg.blocks.add();
    const recurse = try func.dfg.blocks.add();
    const ret0 = try func.dfg.blocks.add();
    const ret1 = try func.dfg.blocks.add(); // trampoline for exit with 1
    const exit = try func.dfg.blocks.add();

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(header);
    try func.layout.appendBlock(check);
    try func.layout.appendBlock(recurse);
    try func.layout.appendBlock(ret0);
    try func.layout.appendBlock(ret1);
    try func.layout.appendBlock(exit);

    // Entry: jump to header with initial params
    try func.dfg.setBlockParams(entry, &.{ Type.I64, Type.I64, Type.I64 });
    const params = func.dfg.blockParams(entry);
    b.switchToBlock(entry);
    try b.jumpArgs(header, &.{ params[0], params[1], params[2] });

    // Header: phi(a, b, c). If c==0 → ret1 else → check
    const phi_a = try func.dfg.appendBlockParam(header, Type.I64);
    const phi_b = try func.dfg.appendBlockParam(header, Type.I64);
    const phi_c = try func.dfg.appendBlockParam(header, Type.I64);
    b.switchToBlock(header);
    const zero = try b.iconst(Type.I64, 0);
    const c_eq_0 = try b.icmp(Type.I64, IntCC.eq, phi_c, zero);
    const one = try b.iconst(Type.I64, 1);
    try b.brif(c_eq_0, ret1, check);

    // Check: if a > b → recurse, else → ret0
    b.switchToBlock(check);
    const a_gt_b = try b.icmp(Type.I64, IntCC.sgt, phi_a, phi_b);
    try b.brif(a_gt_b, recurse, ret0);

    // Recurse: jump header(a, b, c-1) — tail call as jump
    b.switchToBlock(recurse);
    const c_minus_1 = try b.isub(Type.I64, phi_c, one);
    try b.jumpArgs(header, &.{ phi_a, phi_b, c_minus_1 });

    // ret0: jump exit(0)
    b.switchToBlock(ret0);
    try b.jumpArgs(exit, &.{zero});

    // ret1: jump exit(1)
    b.switchToBlock(ret1);
    try b.jumpArgs(exit, &.{one});

    // Exit: return result
    const exit_param = try func.dfg.appendBlockParam(exit, Type.I64);
    b.switchToBlock(exit);
    try b.retValues(&.{exit_param});

    // Compile
    var ctx_builder = ContextBuilder.init(testing.allocator);
    var ctx = ctx_builder.optLevel(.none).callConv(.system_v).verification(false).build();
    defer ctx.deinit();
    var code = try ctx.compileFunction(&func);
    defer code.deinit();

    const mem = try testing.allocator.create(JitMem);
    mem.* = try JitMem.init(testing.allocator, code.code.items.len);
    defer {
        mem.deinit();
        testing.allocator.destroy(mem);
    }
    const buf = try mem.alloc(code.code.items.len, 16);
    try mem.writeExec(buf, code.code.items);
    try mem.setExec(true);

    const f: *const fn (i64, i64, i64) callconv(.c) i64 = @ptrCast(@alignCast(buf.ptr));
    // c==0 → return 1
    try testing.expectEqual(@as(i64, 1), f(5, 3, 0));
    // a > b and c > 0 → loop until c==0 → return 1
    try testing.expectEqual(@as(i64, 1), f(5, 3, 10));
    // a <= b → return 0
    try testing.expectEqual(@as(i64, 0), f(3, 5, 10));
    try testing.expectEqual(@as(i64, 0), f(3, 3, 10));
}
