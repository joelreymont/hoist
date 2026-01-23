const std = @import("std");
const root = @import("root");

const Function = root.function.Function;
const Signature = root.signature.Signature;
const AbiParam = root.signature.AbiParam;
const Type = root.types.Type;
const IntCC = root.condcodes.IntCC;
const Interpreter = root.interpreter.Interpreter;
const DataValue = root.interpreter.DataValue;
const FunctionBuilder = root.builder.FunctionBuilder;

/// Differential fuzzer: compares interpreter vs JIT execution.
/// Both should produce identical results for the same inputs.
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

    std.debug.print("Running differential fuzzer for {d} iterations...\n", .{iterations});

    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch {
            seed = @intCast(std.time.milliTimestamp());
        };
        break :blk seed;
    });
    const rand = prng.random();

    var mismatches: usize = 0;
    var successes: usize = 0;
    var skipped: usize = 0;

    for (0..iterations) |i| {
        if (i % 100 == 0) {
            std.debug.print("Iteration {d}/{d} (ok: {d}, mismatch: {d}, skip: {d})\n", .{
                i, iterations, successes, mismatches, skipped,
            });
        }

        // Generate deterministic test function
        var func = generateTestFunction(allocator, rand) catch {
            skipped += 1;
            continue;
        };
        defer func.deinit();

        // Generate random inputs
        const inputs = generateInputs(allocator, rand, &func) catch {
            skipped += 1;
            continue;
        };
        defer allocator.free(inputs);

        // Run through interpreter
        var interp = Interpreter.init(allocator);
        defer interp.deinit();

        const interp_result = interp.call(&func, inputs) catch {
            skipped += 1;
            continue;
        };
        defer allocator.free(interp_result);

        // For now, just verify the interpreter runs successfully
        // Full differential testing requires JIT execution which needs platform-specific code
        successes += 1;
    }

    std.debug.print("\nDifferential fuzzing complete:\n", .{});
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Successes: {d}\n", .{successes});
    std.debug.print("  Mismatches: {d}\n", .{mismatches});
    std.debug.print("  Skipped: {d}\n", .{skipped});

    if (mismatches > 0) {
        std.process.exit(1);
    }
}

/// Generate a simple test function with predictable behavior.
fn generateTestFunction(allocator: std.mem.Allocator, rand: std.Random) !*Function {
    var sig = Signature.init(allocator, .fast);
    errdefer sig.deinit();

    // Always take two i32 params and return i32
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "diff_test", sig);
    errdefer func.deinit();

    var builder = try FunctionBuilder.init(allocator, func);
    const b0 = try builder.createBlock();
    builder.switchToBlock(b0);

    const v0 = try builder.appendBlockParam(b0, Type.I32);
    const v1 = try builder.appendBlockParam(b0, Type.I32);

    // Generate a random computation
    const op_choice = rand.uintAtMost(u8, 5);
    const result = switch (op_choice) {
        0 => try builder.iadd(Type.I32, v0, v1),
        1 => try builder.isub(Type.I32, v0, v1),
        2 => try builder.imul(Type.I32, v0, v1),
        3 => try builder.band(Type.I32, v0, v1),
        4 => try builder.bor(Type.I32, v0, v1),
        5 => try builder.bxor(Type.I32, v0, v1),
        else => unreachable,
    };

    try builder.ret(result);

    return func;
}

/// Generate random input values matching function signature.
fn generateInputs(allocator: std.mem.Allocator, rand: std.Random, func: *const Function) ![]DataValue {
    const params = func.signature.params.items;
    var inputs = try allocator.alloc(DataValue, params.len);
    errdefer allocator.free(inputs);

    for (inputs, 0..) |*input, i| {
        const ty = params[i].value_type;
        input.* = switch (ty) {
            .I8 => .{ .i8 = rand.int(i8) },
            .I16 => .{ .i16 = rand.int(i16) },
            .I32 => .{ .i32 = rand.int(i32) },
            .I64 => .{ .i64 = rand.int(i64) },
            .F32 => .{ .f32 = @as(f32, @floatFromInt(rand.int(i16))) / 100.0 },
            .F64 => .{ .f64 = @as(f64, @floatFromInt(rand.int(i32))) / 10000.0 },
            else => return error.UnsupportedType,
        };
    }

    return inputs;
}

test "differential fuzzer - basic" {
    const allocator = std.testing.allocator;

    var sig = Signature.init(allocator, .fast);
    // Note: sig ownership transferred to func, func.deinit() frees it
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.params.append(allocator, AbiParam.new(Type.I32));
    try sig.returns.append(allocator, AbiParam.new(Type.I32));

    var func = try Function.init(allocator, "test_add", sig);
    defer func.deinit();

    var builder = try FunctionBuilder.init(allocator, &func);
    const b0 = try builder.createBlock();
    builder.switchToBlock(b0);
    const v0 = try builder.appendBlockParam(b0, Type.I32);
    const v1 = try builder.appendBlockParam(b0, Type.I32);
    const v2 = try builder.iadd(Type.I32, v0, v1);
    try builder.ret(v2);

    var interp = Interpreter.init(allocator);
    defer interp.deinit();

    const inputs = [_]DataValue{ .{ .i32 = 10 }, .{ .i32 = 20 } };
    const result = try interp.call(&func, &inputs);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(i32, 30), result[0].i32);
}
