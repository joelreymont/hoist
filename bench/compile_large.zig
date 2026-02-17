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

/// Benchmark compilation of large functions.
/// Tests scalability with many basic blocks and instructions.
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sizes = [_]usize{ 100, 500, 1000, 5000 };

    std.debug.print("Benchmarking large function compilation...\n", .{});

    var builder = ContextBuilder.init(allocator);
    var ctx = (try builder.targetNative())
        .optLevel(.none)
        .optimization(false)
        .build();
    defer ctx.deinit();

    for (sizes) |size| {
        var timer = try std.time.Timer.start();

        const start = timer.read();
        var func = try createLargeFunction(allocator, size);
        defer func.deinit();
        const ir_time = timer.read() - start;

        const compile_start = timer.read();
        var code = ctx.compileFunction(&func) catch |err| {
            std.debug.print("Size {d}: compilation failed - {}\n", .{ size, err });
            continue;
        };
        defer code.deinit();
        const compile_time = timer.read() - compile_start;

        std.debug.print("Size {d:>5} insts: IR {d:>6}us, compile {d:>6}us, code {d:>5} bytes\n", .{
            size,
            ir_time / 1000,
            compile_time / 1000,
            code.code.items.len,
        });
    }
}

/// Create large function with many sequential arithmetic operations.
fn createLargeFunction(allocator: std.mem.Allocator, num_ops: usize) !Function {
    var sig = Signature.init(allocator, .system_v);
    errdefer sig.deinit();

    try sig.params.append(allocator, AbiParam.new(Type.I64));
    try sig.returns.append(allocator, AbiParam.new(Type.I64));

    var func = try Function.init(allocator, "large", sig);
    errdefer func.deinit();

    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    try func.dfg.setBlockParams(entry, &.{Type.I64});

    var current_val = func.dfg.blockParams(entry)[0];

    // Chain of operations: x + 1 + 2 + 3 + ...
    for (0..num_ops) |i| {
        const const_data = InstructionData{
            .unary_imm = UnaryImmData.init(.iconst, Imm64.new(@intCast(i))),
        };
        const const_inst = try func.dfg.makeInst(const_data);
        const const_val = try func.dfg.appendInstResult(const_inst, Type.I64);
        try func.layout.appendInst(const_inst, entry);

        const add_data = InstructionData{
            .binary = .{
                .opcode = .iadd,
                .args = .{ current_val, const_val },
            },
        };
        const add_inst = try func.dfg.makeInst(add_data);
        const add_result = try func.dfg.appendInstResult(add_inst, Type.I64);
        try func.layout.appendInst(add_inst, entry);

        current_val = add_result;
    }

    const ret_data = InstructionData{
        .unary = .{
            .opcode = .@"return",
            .arg = current_val,
        },
    };
    const ret_inst = try func.dfg.makeInst(ret_data);
    try func.layout.appendInst(ret_inst, entry);

    return func;
}
