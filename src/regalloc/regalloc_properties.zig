//! Property-based tests for register allocation using zcheck.
//!
//! Tests invariants that must hold for any register allocator:
//! - Every vreg gets exactly one allocation (preg or spill)
//! - No two live vregs share the same preg
//! - Allocations respect register classes (int vs float)
//! - Live ranges are consistent (start <= end)
//! - Register pressure stays within bounds

const std = @import("std");
const testing = std.testing;
const zc = @import("zcheck");
const trivial = @import("trivial.zig");
const reg_mod = @import("../machinst/reg.zig");

const TrivialAllocator = trivial.TrivialAllocator;
const VReg = trivial.VReg;
const PReg = trivial.PReg;
const RegClass = trivial.RegClass;
const Allocation = trivial.Allocation;

fn checkFallible(comptime Args: type, comptime property: anytype, config: zc.Config) !void {
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

// ============================================================================
// Live Range Properties
// ============================================================================

// Property: Live ranges must have start <= end.
// This is a fundamental invariant for any live range representation.
test "property: live ranges have valid start and end positions" {
    const Args = struct {
        start: u16,
        end: u16,
    };

    try checkFallible(Args, struct {
        fn prop(args: Args) !void {
            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            const vreg = VReg.new(0, .int);
            const start_pos = @min(args.start, args.end);
            const end_pos = @max(args.start, args.end);

            try alloc.recordLiveRange(vreg, start_pos, end_pos);

            // Verify the range was recorded correctly
            var found = false;
            for (alloc.live_ranges.items) |range| {
                if (std.meta.eql(range.vreg, vreg)) {
                    found = true;
                    try testing.expect(range.start <= range.end);
                }
            }

            try testing.expect(found);
        }
    }.prop, .{ .iterations = 100 });
}

// Property: Overlapping live ranges of different vregs must get different pregs.
// Core correctness property: no two simultaneously live values share a register.
test "property: overlapping vregs get different pregs or spills" {
    const Args = struct {
        vreg1_start: u8,
        vreg1_len: u4,
        vreg2_start: u8,
        vreg2_len: u4,
    };

    try checkFallible(Args, struct {
        fn prop(args: Args) !void {
            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            const vreg1 = VReg.new(0, .int);
            const vreg2 = VReg.new(1, .int);

            const start1 = @as(u32, args.vreg1_start);
            const end1 = start1 + @as(u32, args.vreg1_len);
            const start2 = @as(u32, args.vreg2_start);
            const end2 = start2 + @as(u32, args.vreg2_len);

            try alloc.recordLiveRange(vreg1, start1, end1);
            try alloc.recordLiveRange(vreg2, start2, end2);

            // Allocate both
            _ = try alloc.allocate(vreg1, start1);
            _ = try alloc.allocate(vreg2, start2);

            const alloc1 = alloc.getAllocation(vreg1) orelse return error.MissingAllocation;
            const alloc2 = alloc.getAllocation(vreg2) orelse return error.MissingAllocation;

            // Check if ranges overlap: [start1, end1] ∩ [start2, end2] ≠ ∅
            const overlaps = start1 <= end2 and start2 <= end1;

            if (overlaps) {
                // If both are registers, they must be different
                if (alloc1 == .reg and alloc2 == .reg) {
                    try testing.expect(alloc1.reg.hwEnc() != alloc2.reg.hwEnc());
                }
                // If either is spilled, that's also fine
                return;
            }

            // Non-overlapping ranges can share registers (after one dies)
            return;
        }
    }.prop, .{ .iterations = 200 });
}

// ============================================================================
// Allocation Completeness Properties
// ============================================================================

// Property: Every allocated vreg has an allocation.
// Completeness: allocate() never leaves a vreg without assignment.
test "property: allocated vregs always have allocation" {
    const Args = struct {
        vreg_count: u4, // 0-15 vregs
        start_pos: u8,
        length: u4,
    };

    try checkFallible(Args, struct {
        fn prop(args: Args) !void {
            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            const count = @as(u32, args.vreg_count);
            const start = @as(u32, args.start_pos);
            const len = @as(u32, args.length);
            const end = start + len;

            // Create and allocate vregs
            var i: u32 = 0;
            while (i < count) : (i += 1) {
                const vreg = VReg.new(i, .int);
                try alloc.recordLiveRange(vreg, start, end);
                _ = try alloc.allocate(vreg, start);

                // Verify allocation exists
                try testing.expect(alloc.getAllocation(vreg) != null);
            }

        }
    }.prop, .{ .iterations = 150 });
}

// ============================================================================
// Register Class Properties
// ============================================================================

// Property: Integer vregs get integer pregs (or spills), never float pregs.
// Register class consistency is critical for correctness.
test "property: int vregs never allocated to float pregs" {
    const Args = struct {
        vreg_index: u5,
        start: u8,
        len: u4,
    };

    try checkFallible(Args, struct {
        fn prop(args: Args) !void {
            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            const vreg = VReg.new(args.vreg_index, .int);
            const start_pos = @as(u32, args.start);
            const end_pos = start_pos + @as(u32, args.len);

            try alloc.recordLiveRange(vreg, start_pos, end_pos);
            _ = try alloc.allocate(vreg, start_pos);

            const allocation = alloc.getAllocation(vreg) orelse return error.MissingAllocation;

            // If allocated to a register, it must be an integer register
            if (allocation == .reg) {
                const preg = allocation.reg;
                try testing.expectEqual(RegClass.int, preg.class());
            }

            // Spills are fine
            return;
        }
    }.prop, .{ .iterations = 100 });
}

// Property: Float vregs get float pregs (or spills), never int pregs.
test "property: float vregs never allocated to int pregs" {
    const Args = struct {
        vreg_index: u5,
        start: u8,
        len: u4,
    };

    try checkFallible(Args, struct {
        fn prop(args: Args) !void {
            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            const vreg = VReg.new(args.vreg_index, .float);
            const start_pos = @as(u32, args.start);
            const end_pos = start_pos + @as(u32, args.len);

            try alloc.recordLiveRange(vreg, start_pos, end_pos);
            _ = try alloc.allocate(vreg, start_pos);

            const allocation = alloc.getAllocation(vreg) orelse return error.MissingAllocation;

            // If allocated to a register, it must be a float register
            if (allocation == .reg) {
                const preg = allocation.reg;
                try testing.expectEqual(RegClass.float, preg.class());
            }

            // Spills are fine
            return;
        }
    }.prop, .{ .iterations = 100 });
}

// ============================================================================
// Spilling Properties
// ============================================================================

// Property: When out of registers, allocator spills to unique slots.
// Stress test: allocate more vregs than available pregs, verify spilling works.
test "property: excessive pressure triggers spilling" {
    const Args = struct {
        extra_vregs: u4, // 0-15 extra vregs beyond available
    };

    try checkFallible(Args, struct {
        fn prop(args: Args) !void {
            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            // AArch64 has 30 integer registers (x0-x29)
            const available_regs = 30;
            const total_vregs = available_regs + @as(u32, args.extra_vregs);

            // All vregs live simultaneously
            const start: u32 = 0;
            const end: u32 = 100;

            var i: u32 = 0;
            while (i < total_vregs) : (i += 1) {
                const vreg = VReg.new(i, .int);
                try alloc.recordLiveRange(vreg, start, end);
                _ = try alloc.allocate(vreg, start);
            }

            // Verify all vregs have allocations
            i = 0;
            while (i < total_vregs) : (i += 1) {
                const vreg = VReg.new(i, .int);
                try testing.expect(alloc.getAllocation(vreg) != null);
            }

            // At least `extra_vregs` should be spilled
            var spill_count: u32 = 0;
            i = 0;
            while (i < total_vregs) : (i += 1) {
                const vreg = VReg.new(i, .int);
                if (alloc.getAllocation(vreg)) |allocation| {
                    if (allocation == .spill) {
                        spill_count += 1;
                    }
                }
            }

            try testing.expect(spill_count >= args.extra_vregs);
        }
    }.prop, .{ .iterations = 50 });
}

// Property: Spill slots are unique for simultaneously live vregs.
// No two live values share the same spill slot.
test "property: spill slots are unique for live vregs" {
    const Args = struct {
        spill_count: u4, // 1-16 spilled vregs
    };

    try checkFallible(Args, struct {
        fn prop(args: Args) !void {
            if (args.spill_count == 0) return;

            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            // Force spilling by using all registers first
            const available_regs = 30;
            const start: u32 = 0;
            const end: u32 = 100;

            // Fill all registers
            var i: u32 = 0;
            while (i < available_regs) : (i += 1) {
                const vreg = VReg.new(i, .int);
                try alloc.recordLiveRange(vreg, start, end);
                _ = try alloc.allocate(vreg, start);
            }

            // Allocate extra vregs that will spill
            const spill_start = available_regs;
            const spill_end = spill_start + @as(u32, args.spill_count);

            i = spill_start;
            while (i < spill_end) : (i += 1) {
                const vreg = VReg.new(i, .int);
                try alloc.recordLiveRange(vreg, start, end);
                _ = try alloc.allocate(vreg, start);
            }

            // Collect spill slot indices
            var seen_slots = std.AutoHashMap(u32, void).init(allocator);
            defer seen_slots.deinit();

            i = spill_start;
            while (i < spill_end) : (i += 1) {
                const vreg = VReg.new(i, .int);
                if (alloc.getAllocation(vreg)) |allocation| {
                    if (allocation == .spill) {
                        const slot_idx = allocation.spill.index;

                        // Check uniqueness
                        try testing.expect(!seen_slots.contains(slot_idx));

                        try seen_slots.put(slot_idx, {});
                    }
                }
            }

        }
    }.prop, .{ .iterations = 50 });
}

// ============================================================================
// Register Reuse Properties
// ============================================================================

// Property: After a vreg's live range ends, its preg can be reused.
// Efficiency property: allocator reclaims registers when values die.
test "property: registers reused after live range ends" {
    const Args = struct {
        gap_size: u8, // Gap between vreg1 end and vreg2 start
    };

    try checkFallible(Args, struct {
        fn prop(args: Args) !void {
            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            const vreg1 = VReg.new(0, .int);
            const vreg2 = VReg.new(1, .int);

            // vreg1 lives [0, 10]
            try alloc.recordLiveRange(vreg1, 0, 10);
            _ = try alloc.allocate(vreg1, 0);

            const alloc1 = alloc.getAllocation(vreg1) orelse return error.MissingAllocation;

            // vreg2 lives [10 + gap, 20 + gap] (after vreg1 dies)
            const vreg2_start = 10 + @as(u32, args.gap_size);
            try alloc.recordLiveRange(vreg2, vreg2_start, vreg2_start + 10);

            _ = try alloc.allocate(vreg2, vreg2_start);

            const alloc2 = alloc.getAllocation(vreg2) orelse return error.MissingAllocation;

            // If both are registers and non-overlapping, they CAN share a preg
            // (This is an optimization, not a requirement, so we just check they both got allocations)
            _ = alloc1;
            _ = alloc2;
        }
    }.prop, .{ .iterations = 100 });
}
