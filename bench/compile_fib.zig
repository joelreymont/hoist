const std = @import("std");
const hoist = @import("hoist");

const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const UnaryImmData = hoist.instruction_data.UnaryImmData;
const IntCompareData = hoist.instruction_data.IntCompareData;
const BranchData = hoist.instruction_data.BranchData;
const Imm64 = hoist.immediates.Imm64;
const IntCC = hoist.condcodes.IntCC;
const ContextBuilder = hoist.context.ContextBuilder;
const CompileProfile = hoist.codegen.compile.CompileProfile;
const counting_allocator = @import("counting_allocator.zig");

/// Benchmark compilation of Fibonacci function.
/// Measures IR construction and compilation time.
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var churn_alloc = counting_allocator.CountingAllocator.init(gpa.allocator());
    churn_alloc.reset();
    const allocator = churn_alloc.allocator();

    const iterations = 1000;

    std.debug.print("Benchmarking Fibonacci compilation ({d} iterations)...\n", .{iterations});

    var timer = try std.time.Timer.start();

    var total_ir_time: u64 = 0;
    var total_compile_time: u64 = 0;
    var total_code_size: usize = 0;
    var ir_churn = counting_allocator.Stats{};
    var compile_churn = counting_allocator.Stats{};

    var builder = ContextBuilder.init(allocator);
    var ctx = (try builder.targetNative())
        .optLevel(.aggressive)
        .optimization(true)
        .build();
    defer ctx.deinit();
    ctx.setCompileProfiling(true);
    ctx.resetCompileProfile();

    for (0..iterations) |_| {
        const ir_churn_start = churn_alloc.snapshot();
        // Measure IR construction time
        const ir_start = timer.read();
        var func = try createFibFunction(allocator);
        const ir_end = timer.read();
        total_ir_time += ir_end - ir_start;
        const ir_churn_end = churn_alloc.snapshot();
        ir_churn.addAssign(counting_allocator.Stats.delta(ir_churn_end, ir_churn_start));

        // Measure compilation time
        const compile_churn_start = churn_alloc.snapshot();
        const compile_start = timer.read();
        var code = try ctx.compileFunction(&func);
        const compile_end = timer.read();
        total_compile_time += compile_end - compile_start;

        total_code_size += code.code.items.len;
        code.deinit();
        func.deinit();
        const compile_churn_end = churn_alloc.snapshot();
        compile_churn.addAssign(counting_allocator.Stats.delta(compile_churn_end, compile_churn_start));
    }

    const avg_ir_ns = total_ir_time / iterations;
    const avg_compile_ns = total_compile_time / iterations;
    const avg_code_size = total_code_size / iterations;
    const compile_count = ctx.getCompileCount();
    const stage_sum = ctx.getAccumCompileProfile();

    std.debug.print("\nResults:\n", .{});
    std.debug.print("  Avg IR construction: {d}us\n", .{avg_ir_ns / 1000});
    std.debug.print("  Avg compilation:     {d}us\n", .{avg_compile_ns / 1000});
    std.debug.print("  Avg code size:       {d} bytes\n", .{avg_code_size});
    std.debug.print("  Total time:          {d}ms\n", .{(total_ir_time + total_compile_time) / 1_000_000});
    printChurnAverages("IR", ir_churn, iterations);
    printChurnAverages("compile", compile_churn, iterations);
    printStageAverages(stage_sum, compile_count);
}

fn printStageAverages(sum: CompileProfile, compile_count: u64) void {
    if (compile_count == 0) return;
    std.debug.print("  Stage avg verify:    {d}us\n", .{(sum.verify_ns / compile_count) / 1000});
    std.debug.print("  Stage avg optimize:  {d}us\n", .{(sum.optimize_ns / compile_count) / 1000});
    std.debug.print("  Stage avg lower:     {d}us\n", .{(sum.lower_ns / compile_count) / 1000});
    std.debug.print("  Stage avg regalloc:  {d}us\n", .{(sum.regalloc_ns / compile_count) / 1000});
    std.debug.print("  Stage avg rewrite:   {d}us\n", .{(sum.rewrite_ns / compile_count) / 1000});
    std.debug.print("  Stage avg phi:       {d}us\n", .{(sum.phi_ns / compile_count) / 1000});
    std.debug.print("  Stage avg emit:      {d}us\n", .{(sum.emit_ns / compile_count) / 1000});
    std.debug.print("  Stage avg total:     {d}us\n", .{(sum.total_ns / compile_count) / 1000});
}

fn printChurnAverages(label: []const u8, churn: counting_allocator.Stats, iterations: usize) void {
    const iters_u64: u64 = @intCast(iterations);
    std.debug.print(
        "  Churn {s}: allocs={d} frees={d} resize={d} remap={d} alloc_bytes={d} free_bytes={d}\n",
        .{
            label,
            churn.alloc_calls / iters_u64,
            churn.free_calls / iters_u64,
            churn.resize_calls / iters_u64,
            churn.remap_calls / iters_u64,
            churn.alloc_bytes / iters_u64,
            churn.free_bytes / iters_u64,
        },
    );
}

/// Create IR for Fibonacci function:
/// fn fib(n: i32) -> i32 {
///     if (n <= 1) return n;
///     return fib(n-1) + fib(n-2);
/// }
fn createFibFunction(allocator: std.mem.Allocator) !Function {
    var sig = Signature.init(allocator, .system_v);
    errdefer sig.deinit();

    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "fib", sig);
    errdefer func.deinit();

    // Blocks
    const entry = try func.dfg.makeBlock();
    const base_case = try func.dfg.makeBlock();
    const recursive_case = try func.dfg.makeBlock();

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(base_case);
    try func.layout.appendBlock(recursive_case);

    try func.dfg.setBlockParams(entry, &.{Type.I32});

    const n = func.dfg.blockParams(entry)[0];

    // Entry: if n <= 1 goto base_case else recursive_case
    const one_data = InstructionData{
        .unary_imm = UnaryImmData.init(.iconst, Imm64.new(1)),
    };
    const one_inst = try func.dfg.makeInst(one_data);
    const one_val = try func.dfg.appendInstResult(one_inst, Type.I32);
    try func.layout.appendInst(one_inst, entry);

    const cmp_data = InstructionData{
        .int_compare = IntCompareData.init(.icmp, IntCC.sle, n, one_val),
    };
    const cmp_inst = try func.dfg.makeInst(cmp_data);
    const cmp_result = try func.dfg.appendInstResult(cmp_inst, Type.I8);
    try func.layout.appendInst(cmp_inst, entry);

    const brif_data = InstructionData{
        .branch = BranchData.init(.brif, cmp_result, base_case, recursive_case),
    };
    const brif_inst = try func.dfg.makeInst(brif_data);
    try func.layout.appendInst(brif_inst, entry);

    // Base case: return n
    const ret_base_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = n,
        },
    };
    const ret_base_inst = try func.dfg.makeInst(ret_base_data);
    try func.layout.appendInst(ret_base_inst, base_case);

    // Recursive case: return fib(n-1) + fib(n-2)
    // Note: This is IR-level representation, actual recursion handled by lowering
    const nm1_data = InstructionData{
        .binary = .{
            .opcode = .isub,
            .args = .{ n, one_val },
        },
    };
    const nm1_inst = try func.dfg.makeInst(nm1_data);
    const nm1_val = try func.dfg.appendInstResult(nm1_inst, Type.I32);
    try func.layout.appendInst(nm1_inst, recursive_case);

    const two_data = InstructionData{
        .unary_imm = UnaryImmData.init(.iconst, Imm64.new(2)),
    };
    const two_inst = try func.dfg.makeInst(two_data);
    const two_val = try func.dfg.appendInstResult(two_inst, Type.I32);
    try func.layout.appendInst(two_inst, recursive_case);

    const nm2_data = InstructionData{
        .binary = .{
            .opcode = .isub,
            .args = .{ n, two_val },
        },
    };
    const nm2_inst = try func.dfg.makeInst(nm2_data);
    const nm2_val = try func.dfg.appendInstResult(nm2_inst, Type.I32);
    try func.layout.appendInst(nm2_inst, recursive_case);

    // Simplified: return (n-1) + (n-2) instead of actual recursion
    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ nm1_val, nm2_val },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_result = try func.dfg.appendInstResult(add_inst, Type.I32);
    try func.layout.appendInst(add_inst, recursive_case);

    const ret_rec_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = add_result,
        },
    };
    const ret_rec_inst = try func.dfg.makeInst(ret_rec_data);
    try func.layout.appendInst(ret_rec_inst, recursive_case);

    return func;
}
