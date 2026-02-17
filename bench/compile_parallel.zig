const std = @import("std");
const hoist = @import("hoist");

const Function = hoist.function.Function;
const Signature = hoist.signature.Signature;
const AbiParam = hoist.signature.AbiParam;
const Type = hoist.types.Type;
const InstructionData = hoist.instruction_data.InstructionData;
const UnaryImmData = hoist.instruction_data.UnaryImmData;
const Imm64 = hoist.immediates.Imm64;
const ContextBuilder = hoist.context.ContextBuilder;

const funcs_per_batch: usize = 64;
const rounds: usize = 20;
const ops_per_func: usize = 64;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var funcs = std.ArrayList(Function){};
    defer {
        for (funcs.items) |*func| func.deinit();
        funcs.deinit(allocator);
    }

    try funcs.ensureTotalCapacity(allocator, funcs_per_batch);
    for (0..funcs_per_batch) |idx| {
        const func = try createFunction(allocator, idx);
        try funcs.append(allocator, func);
    }

    var func_ptrs = std.ArrayList(*Function){};
    defer func_ptrs.deinit(allocator);
    try func_ptrs.ensureTotalCapacity(allocator, funcs_per_batch);
    for (funcs.items) |*func| {
        try func_ptrs.append(allocator, func);
    }

    var builder_serial = ContextBuilder.init(allocator);
    var serial_ctx = (try builder_serial.targetNative())
        .optLevel(.aggressive)
        .optimization(true)
        .build();
    defer serial_ctx.deinit();
    serial_ctx.verify = false;

    var builder_parallel = ContextBuilder.init(allocator);
    var parallel_ctx = (try builder_parallel.targetNative())
        .optLevel(.aggressive)
        .optimization(true)
        .build();
    defer parallel_ctx.deinit();
    parallel_ctx.verify = false;

    var timer = try std.time.Timer.start();
    var serial_ns: u64 = 0;
    var parallel_ns: u64 = 0;
    var serial_bytes: usize = 0;
    var parallel_bytes: usize = 0;

    for (0..rounds) |_| {
        const serial_start = timer.read();
        for (funcs.items) |*func| {
            var code = try serial_ctx.compileFunction(func);
            serial_bytes += code.code.items.len;
            code.deinit();
        }
        serial_ns += timer.read() - serial_start;

        const parallel_start = timer.read();
        const results = try parallel_ctx.compileFunctionsParallel(
            func_ptrs.items,
            .{ .num_threads = 0 },
        );
        for (results) |*result| {
            if (result.err != null) return error.ParallelCompileFailed;
            parallel_bytes += result.code.len;
            result.deinit(allocator);
        }
        allocator.free(results);
        parallel_ns += timer.read() - parallel_start;
    }

    const avg_serial_us = (serial_ns / rounds) / 1000;
    const avg_parallel_us = (parallel_ns / rounds) / 1000;
    const speedup = @as(f64, @floatFromInt(avg_serial_us)) /
        @as(f64, @floatFromInt(@max(avg_parallel_us, 1)));

    std.debug.print(
        "Parallel Batch Compile Benchmark ({d} funcs, {d} rounds)\n",
        .{ funcs_per_batch, rounds },
    );
    std.debug.print("  Serial batch compile:   {d}us\n", .{avg_serial_us});
    std.debug.print("  Parallel batch compile: {d}us\n", .{avg_parallel_us});
    std.debug.print("  Parallel speedup:       {d:.2}x\n", .{speedup});
    std.debug.print("  Serial code bytes:      {d}\n", .{serial_bytes / rounds});
    std.debug.print("  Parallel code bytes:    {d}\n", .{parallel_bytes / rounds});
}

fn createFunction(allocator: std.mem.Allocator, idx: usize) !Function {
    var sig = Signature.init(allocator, .system_v);
    errdefer sig.deinit();
    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func_name_buf: [64]u8 = undefined;
    const func_name = try std.fmt.bufPrint(&func_name_buf, "parallel_fn_{d}", .{idx});
    var func = try Function.init(allocator, func_name, sig);
    errdefer func.deinit();

    const block = try func.dfg.makeBlock();
    try func.layout.appendBlock(block);
    try func.dfg.setBlockParams(block, &.{Type.I64});
    var value = func.dfg.blockParams(block)[0];

    for (0..ops_per_func) |op| {
        const cst_inst = try func.dfg.makeInst(.{
            .unary_imm = UnaryImmData.init(.iconst, Imm64.new(@intCast((idx + op) & 0x7fff))),
        });
        const cst = try func.dfg.appendInstResult(cst_inst, Type.I64);
        try func.layout.appendInst(cst_inst, block);

        const add_inst = try func.dfg.makeInst(.{
            .binary = .{
                .opcode = .iadd,
                .args = .{ value, cst },
            },
        });
        value = try func.dfg.appendInstResult(add_inst, Type.I64);
        try func.layout.appendInst(add_inst, block);
    }

    const ret_inst = try func.dfg.makeInst(.{
        .unary = .{
            .opcode = .@"return",
            .arg = value,
        },
    });
    try func.layout.appendInst(ret_inst, block);

    return func;
}
