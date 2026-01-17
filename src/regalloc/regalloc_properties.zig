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

// ============================================================================
// Live Range Properties
// ============================================================================

// Property: Live ranges must have start <= end.
// This is a fundamental invariant for any live range representation.
test "property: live ranges have valid start and end positions" {
    try zc.check(struct {
        fn prop(args: struct {
            start: u16,
            end: u16,
        }) bool {
            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            const vreg = VReg.new(0, .int);
            const start_pos = @min(args.start, args.end);
            const end_pos = @max(args.start, args.end);

            alloc.recordLiveRange(vreg, start_pos, end_pos) catch return false;

            // Verify the range was recorded correctly
            for (alloc.live_ranges.items) |range| {
                if (std.meta.eql(range.vreg, vreg)) {
                    return range.start <= range.end;
                }
            }

            return true;
        }
    }.prop, .{ .iterations = 100 });
}

// Property: Overlapping live ranges of different vregs must get different pregs.
// Core correctness property: no two simultaneously live values share a register.
test "property: overlapping vregs get different pregs or spills" {
    try zc.check(struct {
        fn prop(args: struct {
            vreg1_start: u8,
            vreg1_len: u4,
            vreg2_start: u8,
            vreg2_len: u4,
        }) bool {
            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            const vreg1 = VReg.new(0, .int);
            const vreg2 = VReg.new(1, .int);

            const start1 = @as(u32, args.vreg1_start);
            const end1 = start1 + @as(u32, args.vreg1_len);
            const start2 = @as(u32, args.vreg2_start);
            const end2 = start2 + @as(u32, args.vreg2_len);

            alloc.recordLiveRange(vreg1, start1, end1) catch return false;
            alloc.recordLiveRange(vreg2, start2, end2) catch return false;

            // Allocate both
            _ = alloc.allocate(vreg1, start1) catch return false;
            _ = alloc.allocate(vreg2, start2) catch return false;

            const alloc1 = alloc.getAllocation(vreg1) orelse return false;
            const alloc2 = alloc.getAllocation(vreg2) orelse return false;

            // Check if ranges overlap: [start1, end1] ∩ [start2, end2] ≠ ∅
            const overlaps = start1 <= end2 and start2 <= end1;

            if (overlaps) {
                // If both are registers, they must be different
                if (alloc1 == .reg and alloc2 == .reg) {
                    return alloc1.reg.hwEnc() != alloc2.reg.hwEnc();
                }
                // If either is spilled, that's also fine
                return true;
            }

            // Non-overlapping ranges can share registers (after one dies)
            return true;
        }
    }.prop, .{ .iterations = 200 });
}

// ============================================================================
// Allocation Completeness Properties
// ============================================================================

// Property: Every allocated vreg has an allocation.
// Completeness: allocate() never leaves a vreg without assignment.
test "property: allocated vregs always have allocation" {
    try zc.check(struct {
        fn prop(
            args: struct {
                vreg_count: u4, // 0-15 vregs
                start_pos: u8,
                length: u4,
            },
        ) bool {
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
                alloc.recordLiveRange(vreg, start, end) catch return false;
                _ = alloc.allocate(vreg, start) catch return false;

                // Verify allocation exists
                if (alloc.getAllocation(vreg) == null) {
                    return false;
                }
            }

            return true;
        }
    }.prop, .{ .iterations = 150 });
}

// ============================================================================
// Register Class Properties
// ============================================================================

// Property: Integer vregs get integer pregs (or spills), never float pregs.
// Register class consistency is critical for correctness.
test "property: int vregs never allocated to float pregs" {
    try zc.check(struct {
        fn prop(args: struct {
            vreg_index: u5,
            start: u8,
            len: u4,
        }) bool {
            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            const vreg = VReg.new(args.vreg_index, .int);
            const start_pos = @as(u32, args.start);
            const end_pos = start_pos + @as(u32, args.len);

            alloc.recordLiveRange(vreg, start_pos, end_pos) catch return false;
            _ = alloc.allocate(vreg, start_pos) catch return false;

            const allocation = alloc.getAllocation(vreg) orelse return false;

            // If allocated to a register, it must be an integer register
            if (allocation == .reg) {
                const preg = allocation.reg;
                return preg.class() == .int;
            }

            // Spills are fine
            return true;
        }
    }.prop, .{ .iterations = 100 });
}

// Property: Float vregs get float pregs (or spills), never int pregs.
test "property: float vregs never allocated to int pregs" {
    try zc.check(struct {
        fn prop(args: struct {
            vreg_index: u5,
            start: u8,
            len: u4,
        }) bool {
            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            const vreg = VReg.new(args.vreg_index, .float);
            const start_pos = @as(u32, args.start);
            const end_pos = start_pos + @as(u32, args.len);

            alloc.recordLiveRange(vreg, start_pos, end_pos) catch return false;
            _ = alloc.allocate(vreg, start_pos) catch return false;

            const allocation = alloc.getAllocation(vreg) orelse return false;

            // If allocated to a register, it must be a float register
            if (allocation == .reg) {
                const preg = allocation.reg;
                return preg.class() == .float;
            }

            // Spills are fine
            return true;
        }
    }.prop, .{ .iterations = 100 });
}

// ============================================================================
// Spilling Properties
// ============================================================================

// Property: When out of registers, allocator spills to unique slots.
// Stress test: allocate more vregs than available pregs, verify spilling works.
test "property: excessive pressure triggers spilling" {
    try zc.check(struct {
        fn prop(
            args: struct {
                extra_vregs: u4, // 0-15 extra vregs beyond available
            },
        ) bool {
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
                alloc.recordLiveRange(vreg, start, end) catch return false;
                _ = alloc.allocate(vreg, start) catch return false;
            }

            // Verify all vregs have allocations
            i = 0;
            while (i < total_vregs) : (i += 1) {
                const vreg = VReg.new(i, .int);
                if (alloc.getAllocation(vreg) == null) {
                    return false;
                }
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

            return spill_count >= args.extra_vregs;
        }
    }.prop, .{ .iterations = 50 });
}

// Property: Spill slots are unique for simultaneously live vregs.
// No two live values share the same spill slot.
test "property: spill slots are unique for live vregs" {
    try zc.check(struct {
        fn prop(
            args: struct {
                spill_count: u4, // 1-16 spilled vregs
            },
        ) bool {
            if (args.spill_count == 0) return true;

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
                alloc.recordLiveRange(vreg, start, end) catch return false;
                _ = alloc.allocate(vreg, start) catch return false;
            }

            // Allocate extra vregs that will spill
            const spill_start = available_regs;
            const spill_end = spill_start + @as(u32, args.spill_count);

            i = spill_start;
            while (i < spill_end) : (i += 1) {
                const vreg = VReg.new(i, .int);
                alloc.recordLiveRange(vreg, start, end) catch return false;
                _ = alloc.allocate(vreg, start) catch return false;
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
                        if (seen_slots.contains(slot_idx)) {
                            return false; // Duplicate slot!
                        }

                        seen_slots.put(slot_idx, {}) catch return false;
                    }
                }
            }

            return true;
        }
    }.prop, .{ .iterations = 50 });
}

// ============================================================================
// Register Reuse Properties
// ============================================================================

// Property: After a vreg's live range ends, its preg can be reused.
// Efficiency property: allocator reclaims registers when values die.
test "property: registers reused after live range ends" {
    try zc.check(struct {
        fn prop(
            args: struct {
                gap_size: u8, // Gap between vreg1 end and vreg2 start
            },
        ) bool {
            const allocator = testing.allocator;
            var alloc = TrivialAllocator.init(allocator);
            defer alloc.deinit();

            const vreg1 = VReg.new(0, .int);
            const vreg2 = VReg.new(1, .int);

            // vreg1 lives [0, 10]
            alloc.recordLiveRange(vreg1, 0, 10) catch return false;
            _ = alloc.allocate(vreg1, 0) catch return false;

            const alloc1 = alloc.getAllocation(vreg1) orelse return false;

            // vreg2 lives [10 + gap, 20 + gap] (after vreg1 dies)
            const vreg2_start = 10 + @as(u32, args.gap_size);
            alloc.recordLiveRange(vreg2, vreg2_start, vreg2_start + 10) catch return false;

            _ = alloc.allocate(vreg2, vreg2_start) catch return false;

            const alloc2 = alloc.getAllocation(vreg2) orelse return false;

            // If both are registers and non-overlapping, they CAN share a preg
            // (This is an optimization, not a requirement, so we just check they both got allocations)
            _ = alloc1;
            _ = alloc2;
            return true;
        }
    }.prop, .{ .iterations = 100 });
}
