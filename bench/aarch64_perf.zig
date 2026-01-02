const std = @import("std");
const root = @import("root");

const Function = root.function.Function;
const Signature = root.signature.Signature;
const Type = root.types.Type;
const InstructionData = root.instruction_data.InstructionData;
const ContextBuilder = root.context.ContextBuilder;
const Opcode = root.opcodes.Opcode;

/// Performance benchmark for aarch64 backend.
/// Measures compile time, code size, and instruction throughput.
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("aarch64 Backend Performance Benchmark\n", .{});
    std.debug.print("======================================\n\n", .{});

    try benchmarkIntArithmetic(allocator);
    try benchmarkVectorOps(allocator);
    try benchmarkMemoryOps(allocator);
    try benchmarkMixedWorkload(allocator);
}

fn benchmarkIntArithmetic(allocator: std.mem.Allocator) !void {
    const iterations = 1000;
    std.debug.print("Integer Arithmetic Benchmark ({d} iterations)\n", .{iterations});

    var timer = try std.time.Timer.start();
    var total_time: u64 = 0;
    var total_size: usize = 0;
    var total_insts: usize = 0;

    for (0..iterations) |_| {
        var func = try createIntArithmeticFunction(allocator);
        defer func.deinit();

        const inst_count = func.layout.instCount();
        total_insts += inst_count;

        var ctx = ContextBuilder.init(allocator)
            .target(.aarch64, .linux)
            .optLevel(.speed)
            .optimize(true)
            .build();

        const start = timer.read();
        const code = try ctx.compileFunction(&func);
        const end = timer.read();

        total_time += end - start;
        total_size += code.buffer.len;

        code.deinit(allocator);
    }

    const avg_time_us = (total_time / iterations) / 1000;
    const avg_size = total_size / iterations;
    const avg_insts = total_insts / iterations;

    std.debug.print("  Avg compile time: {d}us\n", .{avg_time_us});
    std.debug.print("  Avg code size:    {d} bytes\n", .{avg_size});
    std.debug.print("  Avg IR insts:     {d}\n", .{avg_insts});
    std.debug.print("  Throughput:       {d:.2} insts/ms\n\n", .{
        @as(f64, @floatFromInt(avg_insts)) / (@as(f64, @floatFromInt(avg_time_us)) / 1000.0),
    });
}

fn benchmarkVectorOps(allocator: std.mem.Allocator) !void {
    const iterations = 1000;
    std.debug.print("Vector Operations Benchmark ({d} iterations)\n", .{iterations});

    var timer = try std.time.Timer.start();
    var total_time: u64 = 0;
    var total_size: usize = 0;
    var total_insts: usize = 0;

    for (0..iterations) |_| {
        var func = try createVectorFunction(allocator);
        defer func.deinit();

        const inst_count = func.layout.instCount();
        total_insts += inst_count;

        var ctx = ContextBuilder.init(allocator)
            .target(.aarch64, .linux)
            .optLevel(.speed)
            .optimize(true)
            .build();

        const start = timer.read();
        const code = try ctx.compileFunction(&func);
        const end = timer.read();

        total_time += end - start;
        total_size += code.buffer.len;

        code.deinit(allocator);
    }

    const avg_time_us = (total_time / iterations) / 1000;
    const avg_size = total_size / iterations;
    const avg_insts = total_insts / iterations;

    std.debug.print("  Avg compile time: {d}us\n", .{avg_time_us});
    std.debug.print("  Avg code size:    {d} bytes\n", .{avg_size});
    std.debug.print("  Avg IR insts:     {d}\n", .{avg_insts});
    std.debug.print("  Throughput:       {d:.2} insts/ms\n\n", .{
        @as(f64, @floatFromInt(avg_insts)) / (@as(f64, @floatFromInt(avg_time_us)) / 1000.0),
    });
}

fn benchmarkMemoryOps(allocator: std.mem.Allocator) !void {
    const iterations = 1000;
    std.debug.print("Memory Operations Benchmark ({d} iterations)\n", .{iterations});

    var timer = try std.time.Timer.start();
    var total_time: u64 = 0;
    var total_size: usize = 0;
    var total_insts: usize = 0;

    for (0..iterations) |_| {
        var func = try createMemoryFunction(allocator);
        defer func.deinit();

        const inst_count = func.layout.instCount();
        total_insts += inst_count;

        var ctx = ContextBuilder.init(allocator)
            .target(.aarch64, .linux)
            .optLevel(.speed)
            .optimize(true)
            .build();

        const start = timer.read();
        const code = try ctx.compileFunction(&func);
        const end = timer.read();

        total_time += end - start;
        total_size += code.buffer.len;

        code.deinit(allocator);
    }

    const avg_time_us = (total_time / iterations) / 1000;
    const avg_size = total_size / iterations;
    const avg_insts = total_insts / iterations;

    std.debug.print("  Avg compile time: {d}us\n", .{avg_time_us});
    std.debug.print("  Avg code size:    {d} bytes\n", .{avg_size});
    std.debug.print("  Avg IR insts:     {d}\n", .{avg_insts});
    std.debug.print("  Throughput:       {d:.2} insts/ms\n\n", .{
        @as(f64, @floatFromInt(avg_insts)) / (@as(f64, @floatFromInt(avg_time_us)) / 1000.0),
    });
}

fn benchmarkMixedWorkload(allocator: std.mem.Allocator) !void {
    const iterations = 1000;
    std.debug.print("Mixed Workload Benchmark ({d} iterations)\n", .{iterations});

    var timer = try std.time.Timer.start();
    var total_time: u64 = 0;
    var total_size: usize = 0;
    var total_insts: usize = 0;

    for (0..iterations) |_| {
        var func = try createMixedFunction(allocator);
        defer func.deinit();

        const inst_count = func.layout.instCount();
        total_insts += inst_count;

        var ctx = ContextBuilder.init(allocator)
            .target(.aarch64, .linux)
            .optLevel(.speed)
            .optimize(true)
            .build();

        const start = timer.read();
        const code = try ctx.compileFunction(&func);
        const end = timer.read();

        total_time += end - start;
        total_size += code.buffer.len;

        code.deinit(allocator);
    }

    const avg_time_us = (total_time / iterations) / 1000;
    const avg_size = total_size / iterations;
    const avg_insts = total_insts / iterations;

    std.debug.print("  Avg compile time: {d}us\n", .{avg_time_us});
    std.debug.print("  Avg code size:    {d} bytes\n", .{avg_size});
    std.debug.print("  Avg IR insts:     {d}\n", .{avg_insts});
    std.debug.print("  Throughput:       {d:.2} insts/ms\n\n", .{
        @as(f64, @floatFromInt(avg_insts)) / (@as(f64, @floatFromInt(avg_time_us)) / 1000.0),
    });
}

/// Create function with integer arithmetic:
/// fn test(a: i64, b: i64, c: i64) -> i64 {
///     let d = a + b;
///     let e = d * c;
///     let f = e - a;
///     let g = f & b;
///     let h = g | c;
///     return h;
/// }
fn createIntArithmeticFunction(allocator: std.mem.Allocator) !Function {
    var sig = try Signature.init(allocator);
    errdefer sig.deinit(allocator);

    const i64_ty = Type{ .int = .{ .width = 64 } };
    try sig.params.append(allocator, i64_ty);
    try sig.params.append(allocator, i64_ty);
    try sig.params.append(allocator, i64_ty);
    try sig.returns.append(allocator, i64_ty);

    var func = try Function.init(allocator, "test_int", sig);
    errdefer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const params = func.dfg.blockParams(entry);
    const a = params[0];
    const b = params[1];
    const c = params[2];

    // d = a + b
    const add_data = InstructionData{ .binary = .{ .opcode = .iadd, .args = .{ a, b } } };
    const add_inst = try func.dfg.makeInst(add_data);
    const d = try func.dfg.appendInstResult(add_inst, i64_ty);
    try func.layout.appendInst(add_inst, entry);

    // e = d * c
    const mul_data = InstructionData{ .binary = .{ .opcode = .imul, .args = .{ d, c } } };
    const mul_inst = try func.dfg.makeInst(mul_data);
    const e = try func.dfg.appendInstResult(mul_inst, i64_ty);
    try func.layout.appendInst(mul_inst, entry);

    // f = e - a
    const sub_data = InstructionData{ .binary = .{ .opcode = .isub, .args = .{ e, a } } };
    const sub_inst = try func.dfg.makeInst(sub_data);
    const f = try func.dfg.appendInstResult(sub_inst, i64_ty);
    try func.layout.appendInst(sub_inst, entry);

    // g = f & b
    const and_data = InstructionData{ .binary = .{ .opcode = .band, .args = .{ f, b } } };
    const and_inst = try func.dfg.makeInst(and_data);
    const g = try func.dfg.appendInstResult(and_inst, i64_ty);
    try func.layout.appendInst(and_inst, entry);

    // h = g | c
    const or_data = InstructionData{ .binary = .{ .opcode = .bor, .args = .{ g, c } } };
    const or_inst = try func.dfg.makeInst(or_data);
    const h = try func.dfg.appendInstResult(or_inst, i64_ty);
    try func.layout.appendInst(or_inst, entry);

    // return h
    const ret_data = InstructionData{ .unary = .{ .opcode = .@"return", .arg = h } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    return func;
}

/// Create function with vector operations:
/// fn test_vec(a: v128, b: v128, c: v128) -> v128 {
///     let d = a + b;
///     let e = d * c;
///     let f = min(e, a);
///     let g = max(f, b);
///     return g;
/// }
fn createVectorFunction(allocator: std.mem.Allocator) !Function {
    var sig = try Signature.init(allocator);
    errdefer sig.deinit(allocator);

    const v128_ty = Type{ .vec = .{ .width = 128, .element = .{ .int = .{ .width = 32 } } } };
    try sig.params.append(allocator, v128_ty);
    try sig.params.append(allocator, v128_ty);
    try sig.params.append(allocator, v128_ty);
    try sig.returns.append(allocator, v128_ty);

    var func = try Function.init(allocator, "test_vec", sig);
    errdefer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const params = func.dfg.blockParams(entry);
    const a = params[0];
    const b = params[1];
    const c = params[2];

    // d = a + b
    const add_data = InstructionData{ .binary = .{ .opcode = .vec_add, .args = .{ a, b } } };
    const add_inst = try func.dfg.makeInst(add_data);
    const d = try func.dfg.appendInstResult(add_inst, v128_ty);
    try func.layout.appendInst(add_inst, entry);

    // e = d * c
    const mul_data = InstructionData{ .binary = .{ .opcode = .vec_mul, .args = .{ d, c } } };
    const mul_inst = try func.dfg.makeInst(mul_data);
    const e = try func.dfg.appendInstResult(mul_inst, v128_ty);
    try func.layout.appendInst(mul_inst, entry);

    // f = min(e, a)
    const min_data = InstructionData{ .binary = .{ .opcode = .vec_min, .args = .{ e, a } } };
    const min_inst = try func.dfg.makeInst(min_data);
    const f = try func.dfg.appendInstResult(min_inst, v128_ty);
    try func.layout.appendInst(min_inst, entry);

    // g = max(f, b)
    const max_data = InstructionData{ .binary = .{ .opcode = .vec_max, .args = .{ f, b } } };
    const max_inst = try func.dfg.makeInst(max_data);
    const g = try func.dfg.appendInstResult(max_inst, v128_ty);
    try func.layout.appendInst(max_inst, entry);

    // return g
    const ret_data = InstructionData{ .unary = .{ .opcode = .@"return", .arg = g } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    return func;
}

/// Create function with memory operations:
/// fn test_mem(ptr: *i64) -> i64 {
///     let a = load(ptr, 0);
///     let b = load(ptr, 8);
///     let c = a + b;
///     store(ptr, 16, c);
///     return c;
/// }
fn createMemoryFunction(allocator: std.mem.Allocator) !Function {
    var sig = try Signature.init(allocator);
    errdefer sig.deinit(allocator);

    const ptr_ty = Type{ .pointer = .{ .pointee = 0 } };
    const i64_ty = Type{ .int = .{ .width = 64 } };

    try sig.params.append(allocator, ptr_ty);
    try sig.returns.append(allocator, i64_ty);

    var func = try Function.init(allocator, "test_mem", sig);
    errdefer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const params = func.dfg.blockParams(entry);
    const ptr = params[0];

    // offset0 = 0
    const off0_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 0 } };
    const off0_inst = try func.dfg.makeInst(off0_data);
    const off0 = try func.dfg.appendInstResult(off0_inst, i64_ty);
    try func.layout.appendInst(off0_inst, entry);

    // a = load(ptr, 0)
    const load0_data = InstructionData{ .load = .{ .addr = ptr, .offset = off0 } };
    const load0_inst = try func.dfg.makeInst(load0_data);
    const a = try func.dfg.appendInstResult(load0_inst, i64_ty);
    try func.layout.appendInst(load0_inst, entry);

    // offset8 = 8
    const off8_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 8 } };
    const off8_inst = try func.dfg.makeInst(off8_data);
    const off8 = try func.dfg.appendInstResult(off8_inst, i64_ty);
    try func.layout.appendInst(off8_inst, entry);

    // b = load(ptr, 8)
    const load8_data = InstructionData{ .load = .{ .addr = ptr, .offset = off8 } };
    const load8_inst = try func.dfg.makeInst(load8_data);
    const b = try func.dfg.appendInstResult(load8_inst, i64_ty);
    try func.layout.appendInst(load8_inst, entry);

    // c = a + b
    const add_data = InstructionData{ .binary = .{ .opcode = .iadd, .args = .{ a, b } } };
    const add_inst = try func.dfg.makeInst(add_data);
    const c = try func.dfg.appendInstResult(add_inst, i64_ty);
    try func.layout.appendInst(add_inst, entry);

    // offset16 = 16
    const off16_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 16 } };
    const off16_inst = try func.dfg.makeInst(off16_data);
    const off16 = try func.dfg.appendInstResult(off16_inst, i64_ty);
    try func.layout.appendInst(off16_inst, entry);

    // store(ptr, 16, c)
    const store_data = InstructionData{ .store = .{ .addr = ptr, .offset = off16, .value = c } };
    const store_inst = try func.dfg.makeInst(store_data);
    try func.layout.appendInst(store_inst, entry);

    // return c
    const ret_data = InstructionData{ .unary = .{ .opcode = .@"return", .arg = c } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    return func;
}

/// Create function with mixed operations
fn createMixedFunction(allocator: std.mem.Allocator) !Function {
    var sig = try Signature.init(allocator);
    errdefer sig.deinit(allocator);

    const i64_ty = Type{ .int = .{ .width = 64 } };
    const ptr_ty = Type{ .pointer = .{ .pointee = 0 } };

    try sig.params.append(allocator, i64_ty);
    try sig.params.append(allocator, i64_ty);
    try sig.params.append(allocator, ptr_ty);
    try sig.returns.append(allocator, i64_ty);

    var func = try Function.init(allocator, "test_mixed", sig);
    errdefer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    const params = func.dfg.blockParams(entry);
    const a = params[0];
    const b = params[1];
    const ptr = params[2];

    // c = a * b
    const mul_data = InstructionData{ .binary = .{ .opcode = .imul, .args = .{ a, b } } };
    const mul_inst = try func.dfg.makeInst(mul_data);
    const c = try func.dfg.appendInstResult(mul_inst, i64_ty);
    try func.layout.appendInst(mul_inst, entry);

    // off = 0
    const off_data = InstructionData{ .nullary = .{ .opcode = .iconst, .imm = 0 } };
    const off_inst = try func.dfg.makeInst(off_data);
    const off = try func.dfg.appendInstResult(off_inst, i64_ty);
    try func.layout.appendInst(off_inst, entry);

    // d = load(ptr, 0)
    const load_data = InstructionData{ .load = .{ .addr = ptr, .offset = off } };
    const load_inst = try func.dfg.makeInst(load_data);
    const d = try func.dfg.appendInstResult(load_inst, i64_ty);
    try func.layout.appendInst(load_inst, entry);

    // e = c + d
    const add_data = InstructionData{ .binary = .{ .opcode = .iadd, .args = .{ c, d } } };
    const add_inst = try func.dfg.makeInst(add_data);
    const e = try func.dfg.appendInstResult(add_inst, i64_ty);
    try func.layout.appendInst(add_inst, entry);

    // store(ptr, 0, e)
    const store_data = InstructionData{ .store = .{ .addr = ptr, .offset = off, .value = e } };
    const store_inst = try func.dfg.makeInst(store_data);
    try func.layout.appendInst(store_inst, entry);

    // return e
    const ret_data = InstructionData{ .unary = .{ .opcode = .@"return", .arg = e } };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    return func;
}
