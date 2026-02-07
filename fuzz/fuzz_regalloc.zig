const std = @import("std");
const hoist = @import("hoist");

const VReg = hoist.reg.VReg;
const PReg = hoist.reg.PReg;
const RegClass = hoist.reg.RegClass;
const LinearScanAllocator = hoist.regalloc.LinearScanAllocator;

/// Fuzzer for register allocation.
/// Generates random allocate/free sequences and validates allocator invariants.
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

    var prng = std.Random.DefaultPrng.init(blk: {
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

        runIteration(allocator, rand) catch |err| {
            std.debug.print("Regalloc iteration failed: {}\n", .{err});
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

fn runIteration(allocator: std.mem.Allocator, rand: std.Random) !void {
    var allocator_inst = LinearScanAllocator.init(allocator);
    defer allocator_inst.deinit();

    var int_regs = try buildRegs(allocator, .int, 16);
    defer int_regs.deinit(allocator);
    var float_regs = try buildRegs(allocator, .float, 16);
    defer float_regs.deinit(allocator);
    var vector_regs = try buildRegs(allocator, .vector, 16);
    defer vector_regs.deinit(allocator);

    try allocator_inst.initRegs(int_regs.items, float_regs.items, vector_regs.items);

    var expected = std.AutoHashMap(VReg, PReg).init(allocator);
    defer expected.deinit();

    var live = std.ArrayList(VReg){};
    defer live.deinit(allocator);

    const steps = rand.uintAtMost(u16, 300) + 50;
    for (0..steps) |_| {
        if (live.items.len > 0 and rand.uintAtMost(u8, 3) == 0) {
            const idx = rand.uintAtMost(usize, live.items.len - 1);
            const vreg = live.swapRemove(idx);
            try allocator_inst.free(vreg);
            _ = expected.remove(vreg);
            if (allocator_inst.getAllocation(vreg) != null) return error.FreeDidNotClearAllocation;
            continue;
        }

        const class = randomClass(rand);
        const idx = rand.uintAtMost(u32, 255);
        const vreg = VReg.new(idx, class);
        const preg = allocator_inst.allocate(vreg) catch |err| switch (err) {
            error.OutOfRegisters => continue,
            else => return err,
        };

        const mapped = allocator_inst.getAllocation(vreg) orelse return error.MissingAllocationEntry;
        if (!pregEq(mapped, preg)) return error.AllocationMapMismatch;

        if (expected.get(vreg)) |prior| {
            if (!pregEq(prior, preg)) return error.NonDeterministicAllocation;
            continue;
        }

        var it = expected.iterator();
        while (it.next()) |entry| {
            const other_vreg = entry.key_ptr.*;
            const other_preg = entry.value_ptr.*;
            if (other_vreg.class() == vreg.class() and pregEq(other_preg, preg)) {
                return error.DuplicatePhysRegAssignment;
            }
        }

        try expected.put(vreg, preg);
        try live.append(allocator, vreg);
    }
}

fn buildRegs(allocator: std.mem.Allocator, class: RegClass, count: usize) !std.ArrayList(PReg) {
    var regs = std.ArrayList(PReg){};
    errdefer regs.deinit(allocator);
    for (0..count) |i| {
        const hw = std.math.cast(u6, i) orelse return error.InvalidRegIndex;
        try regs.append(allocator, PReg.new(class, hw));
    }
    return regs;
}

fn randomClass(rand: std.Random) RegClass {
    return switch (rand.uintAtMost(u8, 2)) {
        0 => .int,
        1 => .float,
        else => .vector,
    };
}

fn pregEq(a: PReg, b: PReg) bool {
    return a.index() == b.index();
}
