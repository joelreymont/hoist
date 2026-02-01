const std = @import("std");
const zc = @import("zcheck");

pub fn checkFallible(comptime Args: type, comptime property: anytype, config: zc.Config) !void {
    var seed: u64 = config.seed;
    var prng: std.Random.DefaultPrng = undefined;
    var random: std.Random = undefined;

    if (config.random) |external| {
        random = external;
    } else {
        if (seed == 0) {
            seed = @as(u64, @intCast(std.time.timestamp()));
        }
        prng = std.Random.DefaultPrng.init(seed);
        random = prng.random();
    }

    var i: usize = 0;
    while (i < config.iterations) : (i += 1) {
        const args = zc.generateWithConfig(Args, random, .{ .use_default_values = config.use_default_values });
        if (property(args)) |_| {} else |err| {
            if (config.expect_failure) return;
            if (config.print_failures) {
                std.debug.print("\n=== Property failed ===\n", .{});
                std.debug.print("Seed: {}\n", .{seed});
                std.debug.print("Iteration: {}\n", .{i});
                std.debug.print("Args: {any}\n", .{args});
                std.debug.print("Error: {s}\n", .{@errorName(err)});
            }
            return err;
        }
    }

    if (config.expect_failure) return error.ExpectedFailure;
}
