const std = @import("std");
const root = @import("root");

const Function = root.function.Function;
const Signature = root.signature.Signature;
const Type = root.types.Type;
const InstructionData = root.instruction_data.InstructionData;
const ContextBuilder = root.context.ContextBuilder;

/// Benchmark compilation of Fibonacci function.
/// Measures IR construction and compilation time.
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const iterations = 1000;

    std.debug.print("Benchmarking Fibonacci compilation ({d} iterations)...\n", .{iterations});

    var timer = try std.time.Timer.start();

    var total_ir_time: u64 = 0;
    var total_compile_time: u64 = 0;
    var total_code_size: usize = 0;

    for (0..iterations) |_| {
        // Measure IR construction time
        const ir_start = timer.read();
        var func = try createFibFunction(allocator);
        const ir_end = timer.read();
        total_ir_time += ir_end - ir_start;

        // Measure compilation time
        var ctx = ContextBuilder.init(allocator)
            .target(.x86_64, .linux)
            .optLevel(.speed)
            .optimize(true)
            .build();

        const compile_start = timer.read();
        const code = try ctx.compileFunction(&func);
        const compile_end = timer.read();
        total_compile_time += compile_end - compile_start;

        total_code_size += code.buffer.len;

        code.deinit(allocator);
        func.deinit();
    }

    const avg_ir_ns = total_ir_time / iterations;
    const avg_compile_ns = total_compile_time / iterations;
    const avg_code_size = total_code_size / iterations;

    std.debug.print("\nResults:\n", .{});
    std.debug.print("  Avg IR construction: {d}us\n", .{avg_ir_ns / 1000});
    std.debug.print("  Avg compilation:     {d}us\n", .{avg_compile_ns / 1000});
    std.debug.print("  Avg code size:       {d} bytes\n", .{avg_code_size});
    std.debug.print("  Total time:          {d}ms\n", .{(total_ir_time + total_compile_time) / 1_000_000});
}

/// Create IR for Fibonacci function:
/// fn fib(n: i32) -> i32 {
///     if (n <= 1) return n;
///     return fib(n-1) + fib(n-2);
/// }
fn createFibFunction(allocator: std.mem.Allocator) !Function {
    var sig = try Signature.init(allocator);
    errdefer sig.deinit(allocator);

    try sig.params.append(allocator, Type{ .int = .{ .width = 32 } });
    try sig.returns.append(allocator, Type{ .int = .{ .width = 32 } });

    var func = try Function.init(allocator, "fib", sig);
    errdefer func.deinit();

    // Blocks
    const entry = try func.dfg.makeBlock();
    const base_case = try func.dfg.makeBlock();
    const recursive_case = try func.dfg.makeBlock();

    try func.layout.appendBlock(entry);
    try func.layout.appendBlock(base_case);
    try func.layout.appendBlock(recursive_case);

    const n = func.dfg.blockParams(entry)[0];

    // Entry: if n <= 1 goto base_case else recursive_case
    const one_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 1,
        },
    };
    const one_inst = try func.dfg.makeInst(one_data);
    const one_val = try func.dfg.appendInstResult(one_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(one_inst, entry);

    const cmp_data = InstructionData{
        .binary = .{
            .opcode = .icmp,
            .args = .{ n, one_val },
        },
    };
    const cmp_inst = try func.dfg.makeInst(cmp_data);
    const cmp_result = try func.dfg.appendInstResult(cmp_inst, Type{ .int = .{ .width = 1 } });
    try func.layout.appendInst(cmp_inst, entry);

    const brif_data = InstructionData{
        .brif = .{
            .condition = cmp_result,
            .then_dest = base_case,
            .else_dest = recursive_case,
        },
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
    const nm1_val = try func.dfg.appendInstResult(nm1_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(nm1_inst, recursive_case);

    const two_data = InstructionData{
        .nullary = .{
            .opcode = .iconst,
            .imm = 2,
        },
    };
    const two_inst = try func.dfg.makeInst(two_data);
    const two_val = try func.dfg.appendInstResult(two_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(two_inst, recursive_case);

    const nm2_data = InstructionData{
        .binary = .{
            .opcode = .isub,
            .args = .{ n, two_val },
        },
    };
    const nm2_inst = try func.dfg.makeInst(nm2_data);
    const nm2_val = try func.dfg.appendInstResult(nm2_inst, Type{ .int = .{ .width = 32 } });
    try func.layout.appendInst(nm2_inst, recursive_case);

    // Simplified: return (n-1) + (n-2) instead of actual recursion
    const add_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ nm1_val, nm2_val },
        },
    };
    const add_inst = try func.dfg.makeInst(add_data);
    const add_result = try func.dfg.appendInstResult(add_inst, Type{ .int = .{ .width = 32 } });
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
