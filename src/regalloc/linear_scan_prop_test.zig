//! Property-based tests for linear scan register allocator.

const std = @import("std");
const testing = std.testing;
const linear_scan_mod = @import("linear_scan.zig");
const liveness_mod = @import("liveness.zig");
const machinst = @import("../machinst/machinst.zig");

test "prop: no two live vregs assigned same preg" {
    const allocator = testing.allocator;
    var prng = std.Random.DefaultPrng.init(0x12345678);
    const random = prng.random();

    for (0..50) |_| {
        // Generate random live ranges
        const num_vregs = random.intRangeAtMost(u32, 2, 20);
        var liveness = liveness_mod.LivenessInfo.init(allocator);
        defer liveness.deinit();

        // Create overlapping ranges
        for (0..num_vregs) |i| {
            const start = random.intRangeAtMost(u32, 0, 100);
            const len = random.intRangeAtMost(u32, 5, 30);
            const end = start + len;
            const reg_class: machinst.RegClass = if (i % 3 == 0) .float else .int;

            try liveness.addRange(.{
                .vreg = machinst.VReg.new(@intCast(i), reg_class),
                .start_inst = start,
                .end_inst = end,
                .reg_class = reg_class,
            });
        }

        // Allocate with small register set to force spills
        var allocator_inst = try linear_scan_mod.LinearScanAllocator.init(
            allocator,
            8, // num_int_regs
            8, // num_float_regs
            8, // num_vector_regs
        );
        defer allocator_inst.deinit();

        var result = try allocator_inst.allocate(&liveness);
        defer result.deinit();

        // Property: For each pair of vregs that interfere, they must not have the same preg
        const ranges = liveness.ranges.items;
        for (ranges, 0..) |range_i, i| {
            const preg_i = result.getPhysReg(range_i.vreg) orelse continue;

            for (ranges[i + 1 ..]) |range_j| {
                if (range_i.overlaps(range_j)) {
                    if (result.getPhysReg(range_j.vreg)) |preg_j| {
                        // Both assigned to pregs - they must be different
                        if (preg_i.class == preg_j.class) {
                            try testing.expect(preg_i.index != preg_j.index);
                        }
                    }
                }
            }
        }
    }
}

test "prop: all vregs get assignment (preg or spill)" {
    const allocator = testing.allocator;
    var prng = std.Random.DefaultPrng.init(0xABCDEF01);
    const random = prng.random();

    for (0..50) |_| {
        const num_vregs = random.intRangeAtMost(u32, 2, 15);
        var liveness = liveness_mod.LivenessInfo.init(allocator);
        defer liveness.deinit();

        for (0..num_vregs) |i| {
            const start = random.intRangeAtMost(u32, 0, 80);
            const len = random.intRangeAtMost(u32, 5, 25);
            const end = start + len;

            try liveness.addRange(.{
                .vreg = machinst.VReg.new(@intCast(i), .int),
                .start_inst = start,
                .end_inst = end,
                .reg_class = .int,
            });
        }

        var allocator_inst = try linear_scan_mod.LinearScanAllocator.init(allocator, 10, 10, 10);
        defer allocator_inst.deinit();

        var result = try allocator_inst.allocate(&liveness);
        defer result.deinit();

        // Property: Every vreg must have either a preg or a spill slot
        for (liveness.ranges.items) |range| {
            const has_preg = result.getPhysReg(range.vreg) != null;
            const has_spill = result.getSpillSlot(range.vreg) != null;

            try testing.expect(has_preg or has_spill);
        }
    }
}

test "prop: spilled vregs have unique or reused slots" {
    const allocator = testing.allocator;
    var prng = std.Random.DefaultPrng.init(0xDEADBEEF);
    const random = prng.random();

    for (0..30) |_| {
        const num_vregs = random.intRangeAtMost(u32, 10, 25);
        var liveness = liveness_mod.LivenessInfo.init(allocator);
        defer liveness.deinit();

        // Create many overlapping ranges to force spills
        for (0..num_vregs) |i| {
            const start = random.intRangeAtMost(u32, 0, 50);
            const len = random.intRangeAtMost(u32, 20, 40);
            const end = start + len;

            try liveness.addRange(.{
                .vreg = machinst.VReg.new(@intCast(i), .int),
                .start_inst = start,
                .end_inst = end,
                .reg_class = .int,
            });
        }

        // Small register set to force spilling
        var allocator_inst = try linear_scan_mod.LinearScanAllocator.init(allocator, 4, 4, 4);
        defer allocator_inst.deinit();

        var result = try allocator_inst.allocate(&liveness);
        defer result.deinit();

        // Collect all spill slots
        var spill_slots = std.ArrayList(u32).init(allocator);
        defer spill_slots.deinit();

        for (liveness.ranges.items) |range| {
            if (result.getSpillSlot(range.vreg)) |slot| {
                try spill_slots.append(allocator, slot.offset);
            }
        }

        // Property: Spill slots for overlapping ranges must be different
        const ranges = liveness.ranges.items;
        for (ranges, 0..) |range_i, i| {
            const slot_i = result.getSpillSlot(range_i.vreg) orelse continue;

            for (ranges[i + 1 ..]) |range_j| {
                if (range_i.overlaps(range_j)) {
                    if (result.getSpillSlot(range_j.vreg)) |slot_j| {
                        // Both spilled and overlap - must have different slots
                        try testing.expect(slot_i.offset != slot_j.offset);
                    }
                }
            }
        }
    }
}

test "prop: hints respected when register available" {
    const allocator = testing.allocator;
    var prng = std.Random.DefaultPrng.init(0xCAFEBABE);
    const random = prng.random();

    for (0..30) |_| {
        const num_vregs = random.intRangeAtMost(u32, 2, 8);
        var liveness = liveness_mod.LivenessInfo.init(allocator);
        defer liveness.deinit();

        // Create non-overlapping ranges so hints can be honored
        var current_pos: u32 = 0;
        for (0..num_vregs) |i| {
            const len = random.intRangeAtMost(u32, 5, 15);
            const gap = random.intRangeAtMost(u32, 2, 5);

            try liveness.addRange(.{
                .vreg = machinst.VReg.new(@intCast(i), .int),
                .start_inst = current_pos,
                .end_inst = current_pos + len,
                .reg_class = .int,
            });

            current_pos += len + gap;
        }

        var allocator_inst = try linear_scan_mod.LinearScanAllocator.init(allocator, 16, 16, 16);
        defer allocator_inst.deinit();

        // Set hints for each vreg
        var hinted_vregs = std.ArrayList(u32).init(allocator);
        defer hinted_vregs.deinit();

        for (0..num_vregs) |i| {
            const vreg = machinst.VReg.new(@intCast(i), .int);
            const hint_reg = machinst.PReg.new(.int, @intCast(i));
            try allocator_inst.setHint(vreg, hint_reg);
            try hinted_vregs.append(allocator, @intCast(i));
        }

        var result = try allocator_inst.allocate(&liveness);
        defer result.deinit();

        // Property: When ranges don't overlap and plenty of regs, hints should be honored
        var hints_honored: u32 = 0;
        for (hinted_vregs.items) |vreg_idx| {
            const vreg = machinst.VReg.new(vreg_idx, .int);
            if (result.getPhysReg(vreg)) |preg| {
                if (preg.index == vreg_idx) {
                    hints_honored += 1;
                }
            }
        }

        // At least 60% of hints should be honored when there's no pressure
        const threshold = (num_vregs * 60) / 100;
        try testing.expect(hints_honored >= threshold);
    }
}

test "prop: register allocation is deterministic" {
    const allocator = testing.allocator;

    // Create fixed liveness info
    var liveness = liveness_mod.LivenessInfo.init(allocator);
    defer liveness.deinit();

    try liveness.addRange(.{
        .vreg = machinst.VReg.new(0, .int),
        .start_inst = 0,
        .end_inst = 10,
        .reg_class = .int,
    });
    try liveness.addRange(.{
        .vreg = machinst.VReg.new(1, .int),
        .start_inst = 5,
        .end_inst = 15,
        .reg_class = .int,
    });
    try liveness.addRange(.{
        .vreg = machinst.VReg.new(2, .int),
        .start_inst = 12,
        .end_inst = 20,
        .reg_class = .int,
    });

    // Run allocation twice
    var allocator_inst1 = try linear_scan_mod.LinearScanAllocator.init(allocator, 10, 10, 10);
    defer allocator_inst1.deinit();

    var result1 = try allocator_inst1.allocate(&liveness);
    defer result1.deinit();

    var allocator_inst2 = try linear_scan_mod.LinearScanAllocator.init(allocator, 10, 10, 10);
    defer allocator_inst2.deinit();

    var result2 = try allocator_inst2.allocate(&liveness);
    defer result2.deinit();

    // Property: Results should be identical
    for (0..3) |i| {
        const vreg = machinst.VReg.new(@intCast(i), .int);

        const preg1 = result1.getPhysReg(vreg);
        const preg2 = result2.getPhysReg(vreg);

        if (preg1) |p1| {
            const p2 = preg2.?;
            try testing.expectEqual(p1.index, p2.index);
            try testing.expectEqual(p1.class, p2.class);
        } else {
            try testing.expectEqual(preg1, preg2);
        }

        const spill1 = result1.getSpillSlot(vreg);
        const spill2 = result2.getSpillSlot(vreg);

        if (spill1) |s1| {
            const s2 = spill2.?;
            try testing.expectEqual(s1.offset, s2.offset);
        } else {
            try testing.expectEqual(spill1, spill2);
        }
    }
}
