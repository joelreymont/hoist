const std = @import("std");
const root = @import("root");

const Function = root.function.Function;
const Signature = root.signature.Signature;
const Type = root.types.Type;
const InstructionData = root.instruction_data.InstructionData;
const Opcode = root.opcodes.Opcode;
const ContextBuilder = root.context.ContextBuilder;

/// Fuzzer for compilation pipeline.
/// Generates random valid IR and attempts to compile it.
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const iterations: usize = if (args.len > 1)
        try std.fmt.parseInt(usize, args[1], 10)
    else
        1000;

    std.debug.print("Running compilation fuzzer for {d} iterations...\n", .{iterations});

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    var crashes: usize = 0;
    var successes: usize = 0;

    for (0..iterations) |i| {
        if (i % 100 == 0) {
            std.debug.print("Iteration {d}/{d} (crashes: {d}, successes: {d})\n", .{ i, iterations, crashes, successes });
        }

        // Generate random IR function
        var func = generateRandomFunction(allocator, rand) catch |err| {
            std.debug.print("Failed to generate function: {}\n", .{err});
            crashes += 1;
            continue;
        };
        defer func.deinit();

        // Try to compile it
        var ctx = ContextBuilder.init(allocator)
            .target(if (rand.boolean()) .x86_64 else .aarch64, .linux)
            .optLevel(.none)
            .verify(true)
            .optimize(rand.boolean())
            .build();

        const code = ctx.compileFunction(&func) catch |err| {
            // Compilation failure is expected for some random IR
            std.debug.print("Compilation failed (expected): {}\n", .{err});
            continue;
        };
        defer code.deinit(allocator);

        successes += 1;
    }

    std.debug.print("\nFuzzing complete:\n", .{});
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Successes: {d}\n", .{successes});
    std.debug.print("  Crashes: {d}\n", .{crashes});

    if (crashes > 0) {
        std.process.exit(1);
    }
}

/// Generate a random valid IR function.
fn generateRandomFunction(allocator: std.mem.Allocator, rand: std.rand.Random) !Function {
    // Create signature with random parameters and return
    var sig = try Signature.init(allocator);
    errdefer sig.deinit(allocator);

    const num_params = rand.uintAtMost(u8, 4);
    for (0..num_params) |_| {
        try sig.params.append(allocator, randomType(rand));
    }

    if (rand.boolean()) {
        try sig.returns.append(allocator, randomType(rand));
    }

    var func = try Function.init(allocator, "fuzz_test", sig);
    errdefer func.deinit();

    // Create entry block
    const entry = try func.dfg.makeBlock();
    try func.layout.appendBlock(entry);

    // Generate random instructions
    const num_insts = rand.uintAtMost(u8, 10) + 1;

    var values = std.ArrayList(root.entities.Value).init(allocator);
    defer values.deinit();

    // Add parameters as available values
    const params = func.dfg.blockParams(entry);
    try values.appendSlice(params);

    for (0..num_insts) |_| {
        const inst = try generateRandomInstruction(allocator, &func, rand, values.items);
        try func.layout.appendInst(inst, entry);

        // Add instruction results to available values
        const results = func.dfg.instResults(inst);
        try values.appendSlice(results);
    }

    // Always end with return
    const ret_inst = try generateReturnInstruction(&func, rand, values.items, sig.returns.items);
    try func.layout.appendInst(ret_inst, entry);

    return func;
}

/// Generate a random type.
fn randomType(rand: std.rand.Random) Type {
    const width_choices = [_]u8{ 8, 16, 32, 64 };
    const width = width_choices[rand.uintAtMost(usize, width_choices.len - 1)];
    return Type{ .int = .{ .width = width } };
}

/// Generate a random instruction.
fn generateRandomInstruction(
    allocator: std.mem.Allocator,
    func: *Function,
    rand: std.rand.Random,
    available_values: []root.entities.Value,
) !root.entities.Inst {
    _ = allocator;

    const opcode_choices = [_]Opcode{
        .iadd,
        .isub,
        .imul,
        .band,
        .bor,
        .bxor,
        .iconst,
    };

    const opcode = opcode_choices[rand.uintAtMost(usize, opcode_choices.len - 1)];

    switch (opcode) {
        .iconst => {
            const imm_val = rand.int(i32);
            const inst_data = InstructionData{
                .nullary = .{
                    .opcode = .iconst,
                    .imm = @intCast(imm_val),
                },
            };
            const inst = try func.dfg.makeInst(inst_data);
            _ = try func.dfg.appendInstResult(inst, randomType(rand));
            return inst;
        },
        .iadd, .isub, .imul, .band, .bor, .bxor => {
            if (available_values.len < 2) {
                // Not enough values, make a constant
                return generateRandomInstruction(allocator, func, rand, available_values);
            }

            const lhs = available_values[rand.uintAtMost(usize, available_values.len - 1)];
            const rhs = available_values[rand.uintAtMost(usize, available_values.len - 1)];

            const inst_data = InstructionData{
                .binary = .{
                    .opcode = opcode,
                    .args = .{ lhs, rhs },
                },
            };
            const inst = try func.dfg.makeInst(inst_data);

            // Result type should match operand types
            const lhs_ty = func.dfg.valueType(lhs);
            _ = try func.dfg.appendInstResult(inst, lhs_ty);
            return inst;
        },
        else => unreachable,
    }
}

/// Generate a return instruction.
fn generateReturnInstruction(
    func: *Function,
    rand: std.rand.Random,
    available_values: []root.entities.Value,
    return_types: []const Type,
) !root.entities.Inst {
    if (return_types.len == 0) {
        // Void return
        const inst_data = InstructionData{
            .nullary = .{
                .opcode = .@"return",
                .imm = 0,
            },
        };
        return try func.dfg.makeInst(inst_data);
    } else {
        // Pick a random value to return
        if (available_values.len == 0) {
            // No values available, create a constant
            const inst_data = InstructionData{
                .nullary = .{
                    .opcode = .iconst,
                    .imm = 0,
                },
            };
            const const_inst = try func.dfg.makeInst(inst_data);
            const const_val = try func.dfg.appendInstResult(const_inst, return_types[0]);

            const ret_data = InstructionData{
                .unary = .{
                    .opcode = .@"return",
                    .arg = const_val,
                },
            };
            return try func.dfg.makeInst(ret_data);
        }

        const ret_val = available_values[rand.uintAtMost(usize, available_values.len - 1)];
        const inst_data = InstructionData{
            .unary = .{
                .opcode = .@"return",
                .arg = ret_val,
            },
        };
        return try func.dfg.makeInst(inst_data);
    }
}
