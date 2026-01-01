const std = @import("std");
const root = @import("root");

const VCode = root.vcode.VCode;
const VReg = root.reg.VReg;
const PReg = root.reg.PReg;
const RegClass = root.reg.RegClass;
const LinearScanAllocator = root.regalloc.LinearScanAllocator;

/// Fuzzer for register allocation.
/// Generates random VCode with virtual registers and tests allocator.
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

    std.debug.print("Running regalloc fuzzer for {d} iterations...\n", .{iterations});

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

        // Generate random VCode
        var vcode = generateRandomVCode(allocator, rand) catch |err| {
            std.debug.print("Failed to generate vcode: {}\n", .{err});
            crashes += 1;
            continue;
        };
        defer vcode.deinit();

        // Try to allocate registers
        var allocator_inst = LinearScanAllocator.init(allocator, &vcode);
        defer allocator_inst.deinit();

        allocator_inst.run() catch |err| {
            std.debug.print("Register allocation failed: {}\n", .{err});
            crashes += 1;
            continue;
        };

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

/// Generate random VCode for testing.
fn generateRandomVCode(allocator: std.mem.Allocator, rand: std.rand.Random) !VCode {
    var vcode = VCode.init(allocator);
    errdefer vcode.deinit();

    const num_vregs = rand.uintAtMost(u32, 50) + 10;

    // Create virtual registers
    var vregs = std.ArrayList(VReg).init(allocator);
    defer vregs.deinit();

    for (0..num_vregs) |i| {
        const class: RegClass = if (rand.boolean()) .int else .float;
        const vreg = VReg.new(class, @intCast(i));
        try vregs.append(vreg);
    }

    // Generate random instructions using these vregs
    const num_blocks = rand.uintAtMost(u32, 5) + 1;

    for (0..num_blocks) |_| {
        const block_id = try vcode.newBlock();

        const num_insts = rand.uintAtMost(u32, 20) + 5;
        for (0..num_insts) |_| {
            // For now, just create dummy instruction metadata
            // In real implementation, would create actual VInst
            _ = block_id;
            _ = vregs;
        }
    }

    return vcode;
}
