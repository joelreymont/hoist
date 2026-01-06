//! Linear scan register allocation algorithm.
//!
//! This is a fast register allocation algorithm that makes a single linear pass
//! over the live ranges of virtual registers, allocating physical registers
//! greedily. It's faster than graph-coloring but may produce slightly worse code.
//!
//! The algorithm maintains three sets of intervals:
//! - active: intervals currently live
//! - inactive: intervals that have a hole at the current position
//! - free_regs: available physical registers per register class

const std = @import("std");
const liveness = @import("liveness.zig");
const machinst = @import("../machinst/machinst.zig");

/// A spill slot represents a location on the stack for a spilled virtual register.
/// The offset is in bytes from the stack frame base.
pub const SpillSlot = struct {
    offset: u32,

    pub fn init(offset: u32) SpillSlot {
        return .{ .offset = offset };
    }
};

/// Result of register allocation.
pub const RegAllocResult = struct {
    /// Map from virtual register index to physical register
    vreg_to_preg: std.AutoHashMap(u32, machinst.PReg),

    /// Map from virtual register index to spill slot
    vreg_to_spill: std.AutoHashMap(u32, SpillSlot),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RegAllocResult {
        return .{
            .vreg_to_preg = std.AutoHashMap(u32, machinst.PReg).init(allocator),
            .vreg_to_spill = std.AutoHashMap(u32, SpillSlot).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RegAllocResult) void {
        self.vreg_to_preg.deinit();
        self.vreg_to_spill.deinit();
    }

    /// Get the physical register allocated to a virtual register
    pub fn getPhysReg(self: *RegAllocResult, vreg: machinst.VReg) ?machinst.PReg {
        return self.vreg_to_preg.get(vreg.index);
    }

    /// Assign a physical register to a virtual register
    pub fn assign(self: *RegAllocResult, vreg: machinst.VReg, preg: machinst.PReg) !void {
        try self.vreg_to_preg.put(vreg.index, preg);
    }

    /// Get the spill slot for a virtual register
    pub fn getSpillSlot(self: *RegAllocResult, vreg: machinst.VReg) ?SpillSlot {
        return self.vreg_to_spill.get(vreg.index);
    }

    /// Assign a spill slot to a virtual register
    pub fn assignSpillSlot(self: *RegAllocResult, vreg: machinst.VReg, slot: SpillSlot) !void {
        try self.vreg_to_spill.put(vreg.index, slot);
    }
};

/// Linear scan register allocator.
///
/// This allocator processes live ranges in order of their start position,
/// assigning physical registers greedily. When no register is available,
/// it spills the interval that interferes and has the furthest next use.
pub const LinearScanAllocator = struct {
    /// Live ranges currently active (overlapping current position)
    active: std.ArrayList(liveness.LiveRange),

    /// Live ranges that are inactive (have a hole at current position)
    /// Not used in the simple version, but needed for more advanced variants
    inactive: std.ArrayList(liveness.LiveRange),

    /// Available physical registers per register class
    /// We track which physical registers are free for allocation
    free_int_regs: std.DynamicBitSet,
    free_float_regs: std.DynamicBitSet,
    free_vector_regs: std.DynamicBitSet,

    /// Number of physical registers per class
    num_int_regs: u32,
    num_float_regs: u32,
    num_vector_regs: u32,

    /// Next available spill slot offset (in bytes)
    next_spill_offset: u32,

    allocator: std.mem.Allocator,

    /// Initialize the allocator with the number of physical registers available
    /// per register class.
    ///
    /// For AArch64:
    /// - int: 31 general-purpose registers (X0-X30)
    /// - float: 32 SIMD/FP registers (V0-V31)
    /// - vector: 32 vector registers (same as float)
    pub fn init(
        allocator: std.mem.Allocator,
        num_int_regs: u32,
        num_float_regs: u32,
        num_vector_regs: u32,
    ) !LinearScanAllocator {
        var free_int = try std.DynamicBitSet.initFull(allocator, num_int_regs);
        errdefer free_int.deinit();

        var free_float = try std.DynamicBitSet.initFull(allocator, num_float_regs);
        errdefer free_float.deinit();

        var free_vector = try std.DynamicBitSet.initFull(allocator, num_vector_regs);
        errdefer free_vector.deinit();

        return .{
            .active = std.ArrayList(liveness.LiveRange).init(allocator),
            .inactive = std.ArrayList(liveness.LiveRange).init(allocator),
            .free_int_regs = free_int,
            .free_float_regs = free_float,
            .free_vector_regs = free_vector,
            .num_int_regs = num_int_regs,
            .num_float_regs = num_float_regs,
            .num_vector_regs = num_vector_regs,
            .next_spill_offset = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LinearScanAllocator) void {
        self.active.deinit();
        self.inactive.deinit();
        self.free_int_regs.deinit();
        self.free_float_regs.deinit();
        self.free_vector_regs.deinit();
    }

    /// Perform linear scan register allocation.
    ///
    /// Takes liveness information and produces a mapping from virtual registers
    /// to physical registers.
    ///
    /// The main allocation loop processes live ranges in order of their start
    /// position, maintaining the active list and allocating registers greedily.
    pub fn allocate(
        self: *LinearScanAllocator,
        liveness_info: *liveness.LivenessInfo,
    ) !RegAllocResult {
        var result = RegAllocResult.init(self.allocator);
        errdefer result.deinit();

        // Get live ranges sorted by start position
        const sorted_ranges = try liveness_info.getRangesSortedByStart();
        defer self.allocator.free(sorted_ranges);

        // Main allocation loop: process each live range in order
        for (sorted_ranges) |range| {
            // Expire old intervals that have ended before this range starts
            try self.expireOldIntervals(range.start_inst, &result);

            // Try to allocate a free register for this range
            const maybe_preg = try self.tryAllocateReg(range, &result);

            if (maybe_preg == null) {
                // No free register available - try spilling
                const spilled_reg = try self.spillInterval(range, &result);

                if (spilled_reg) |preg| {
                    // Successfully spilled - allocate the freed register
                    try result.assign(range.vreg, preg);
                    const free_regs = self.getFreeRegs(range.reg_class);
                    free_regs.unset(preg.index);
                    try self.active.append(self.allocator, range);
                } else {
                    // No suitable spill candidate - out of registers
                    return error.OutOfRegisters;
                }
            }
        }

        return result;
    }

    /// Expire old intervals that are no longer active.
    ///
    /// This removes intervals from the active list that have ended before
    /// the current position, freeing up their physical registers for reuse.
    ///
    /// Must be called before processing each new interval to maintain
    /// the invariant that all intervals in the active list overlap the
    /// current position.
    fn expireOldIntervals(
        self: *LinearScanAllocator,
        current_pos: u32,
        result: *RegAllocResult,
    ) !void {
        // Iterate through active intervals in order
        // Remove those that have ended before current_pos
        var i: usize = 0;
        while (i < self.active.items.len) {
            const range = self.active.items[i];

            if (range.end_inst < current_pos) {
                // This interval has ended - free its register
                const preg = result.getPhysReg(range.vreg) orelse {
                    // No register was assigned (shouldn't happen)
                    i += 1;
                    continue;
                };

                // Mark the register as free
                const free_regs = self.getFreeRegs(range.reg_class);
                free_regs.set(preg.index);

                // Remove from active list (swap with last element for O(1) removal)
                _ = self.active.swapRemove(i);
                // Don't increment i - we need to check the element that was swapped here
            } else {
                // Still active - intervals are sorted by end time, so we can stop
                // Actually, they're sorted by start time, so we need to check all
                i += 1;
            }
        }
    }

    /// Try to allocate a physical register for the given live range.
    ///
    /// Searches for a free register of the appropriate class. If one is found:
    /// - Allocates it to the vreg
    /// - Marks the register as used
    /// - Adds the range to the active list
    /// - Returns the allocated register
    ///
    /// If no register is available, returns null (caller should spill).
    fn tryAllocateReg(
        self: *LinearScanAllocator,
        range: liveness.LiveRange,
        result: *RegAllocResult,
    ) !?machinst.PReg {
        const free_regs = self.getFreeRegs(range.reg_class);

        // Find first free register
        var reg_idx: u32 = 0;
        const num_regs = self.getNumRegs(range.reg_class);
        while (reg_idx < num_regs) : (reg_idx += 1) {
            if (free_regs.isSet(reg_idx)) {
                // Found a free register!
                const preg = machinst.PReg.new(range.reg_class, reg_idx);

                // Assign it to the vreg
                try result.assign(range.vreg, preg);

                // Mark as used
                free_regs.unset(reg_idx);

                // Add to active list
                try self.active.append(self.allocator, range);

                return preg;
            }
        }

        // No free register available
        return null;
    }

    /// Spill an active interval to free up a register.
    ///
    /// Chooses the active interval with the furthest next use (approximated as
    /// the interval that ends latest) and evicts it from the active list.
    /// This frees up its physical register for allocation to the current range.
    ///
    /// Returns the freed register, or null if no suitable spill candidate exists.
    fn spillInterval(
        self: *LinearScanAllocator,
        range: liveness.LiveRange,
        result: *RegAllocResult,
    ) !?machinst.PReg {
        // Find the active interval of the same register class with the furthest end
        var best_idx: ?usize = null;
        var best_end: u32 = range.end_inst;

        for (self.active.items, 0..) |active_range, idx| {
            // Only consider intervals of the same register class
            if (active_range.reg_class != range.reg_class) continue;

            // Find interval that ends furthest in the future
            if (active_range.end_inst > best_end) {
                best_end = active_range.end_inst;
                best_idx = idx;
            }
        }

        // If no candidate found, spilling won't help
        const spill_idx = best_idx orelse return null;

        // Get the interval to spill
        const spill_range = self.active.items[spill_idx];

        // Get its allocated register
        const preg = result.getPhysReg(spill_range.vreg) orelse return null;

        // Remove from active list
        _ = self.active.swapRemove(spill_idx);

        // Mark register as free
        const free_regs = self.getFreeRegs(spill_range.reg_class);
        free_regs.set(preg.index);

        // Allocate a spill slot for the spilled vreg
        const spill_slot = self.allocateSpillSlot();
        try result.assignSpillSlot(spill_range.vreg, spill_slot);

        return preg;
    }

    /// Allocate a new spill slot on the stack.
    ///
    /// Returns a SpillSlot with the next available stack offset.
    /// Spill slots are allocated in 8-byte increments to maintain alignment.
    fn allocateSpillSlot(self: *LinearScanAllocator) SpillSlot {
        const slot = SpillSlot.init(self.next_spill_offset);
        self.next_spill_offset += 8; // 8-byte slots for all types
        return slot;
    }

    /// Get the bitset for free registers of a given class
    fn getFreeRegs(self: *LinearScanAllocator, class: machinst.RegClass) *std.DynamicBitSet {
        return switch (class) {
            .int => &self.free_int_regs,
            .float => &self.free_float_regs,
            .vector => &self.free_vector_regs,
        };
    }

    /// Get the number of registers for a given class
    fn getNumRegs(self: *LinearScanAllocator, class: machinst.RegClass) u32 {
        return switch (class) {
            .int => self.num_int_regs,
            .float => self.num_float_regs,
            .vector => self.num_vector_regs,
        };
    }
};

test "LinearScanAllocator init/deinit" {
    const allocator = std.testing.allocator;

    var lsa = try LinearScanAllocator.init(allocator, 31, 32, 32);
    defer lsa.deinit();

    try std.testing.expectEqual(@as(u32, 31), lsa.num_int_regs);
    try std.testing.expectEqual(@as(u32, 32), lsa.num_float_regs);
    try std.testing.expectEqual(@as(u32, 32), lsa.num_vector_regs);

    // All registers should be free initially
    try std.testing.expectEqual(@as(usize, 31), lsa.free_int_regs.count());
    try std.testing.expectEqual(@as(usize, 32), lsa.free_float_regs.count());
    try std.testing.expectEqual(@as(usize, 32), lsa.free_vector_regs.count());
}

test "RegAllocResult basic operations" {
    const allocator = std.testing.allocator;

    var result = RegAllocResult.init(allocator);
    defer result.deinit();

    const vreg0 = machinst.VReg.new(0, .int);
    const preg0 = machinst.PReg.new(.int, 5);

    try result.assign(vreg0, preg0);

    const assigned = result.getPhysReg(vreg0);
    try std.testing.expect(assigned != null);
    try std.testing.expectEqual(preg0.index, assigned.?.index);
    try std.testing.expectEqual(preg0.class, assigned.?.class);
}

test "LinearScanAllocator non-overlapping ranges" {
    const allocator = std.testing.allocator;

    var lsa = try LinearScanAllocator.init(allocator, 31, 32, 32);
    defer lsa.deinit();

    var info = liveness.LivenessInfo.init(allocator);
    defer info.deinit();

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .int);

    // Two non-overlapping ranges
    try info.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 5,
        .reg_class = .int,
    });

    try info.addRange(.{
        .vreg = v1,
        .start_inst = 10,
        .end_inst = 15,
        .reg_class = .int,
    });

    var result = try lsa.allocate(&info);
    defer result.deinit();

    // Both should be allocated (can reuse same register)
    const p0 = result.getPhysReg(v0);
    const p1 = result.getPhysReg(v1);

    try std.testing.expect(p0 != null);
    try std.testing.expect(p1 != null);

    // Both should be int registers
    try std.testing.expectEqual(machinst.RegClass.int, p0.?.class);
    try std.testing.expectEqual(machinst.RegClass.int, p1.?.class);
}

test "LinearScanAllocator overlapping ranges get different registers" {
    const allocator = std.testing.allocator;

    var lsa = try LinearScanAllocator.init(allocator, 31, 32, 32);
    defer lsa.deinit();

    var info = liveness.LivenessInfo.init(allocator);
    defer info.deinit();

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .int);

    // Two overlapping ranges
    try info.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 10,
        .reg_class = .int,
    });

    try info.addRange(.{
        .vreg = v1,
        .start_inst = 5,
        .end_inst = 15,
        .reg_class = .int,
    });

    var result = try lsa.allocate(&info);
    defer result.deinit();

    // Both should be allocated
    const p0 = result.getPhysReg(v0);
    const p1 = result.getPhysReg(v1);

    try std.testing.expect(p0 != null);
    try std.testing.expect(p1 != null);

    // They should have different register indices (can't share)
    try std.testing.expect(p0.?.index != p1.?.index);
}

test "LinearScanAllocator register reuse after expiry" {
    const allocator = std.testing.allocator;

    var lsa = try LinearScanAllocator.init(allocator, 2, 2, 2); // Only 2 int regs
    defer lsa.deinit();

    var info = liveness.LivenessInfo.init(allocator);
    defer info.deinit();

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .int);
    const v2 = machinst.VReg.new(2, .int);

    // v0: [0, 5]
    // v1: [0, 5] (overlaps v0)
    // v2: [10, 15] (after both expire)
    try info.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 5,
        .reg_class = .int,
    });

    try info.addRange(.{
        .vreg = v1,
        .start_inst = 0,
        .end_inst = 5,
        .reg_class = .int,
    });

    try info.addRange(.{
        .vreg = v2,
        .start_inst = 10,
        .end_inst = 15,
        .reg_class = .int,
    });

    var result = try lsa.allocate(&info);
    defer result.deinit();

    // All three should be allocated
    const p0 = result.getPhysReg(v0);
    const p1 = result.getPhysReg(v1);
    const p2 = result.getPhysReg(v2);

    try std.testing.expect(p0 != null);
    try std.testing.expect(p1 != null);
    try std.testing.expect(p2 != null);

    // v0 and v1 must be different (overlapping)
    try std.testing.expect(p0.?.index != p1.?.index);

    // v2 should reuse one of the registers from v0 or v1
    try std.testing.expect(p2.?.index == p0.?.index or p2.?.index == p1.?.index);
}

test "LinearScanAllocator different register classes independent" {
    const allocator = std.testing.allocator;

    var lsa = try LinearScanAllocator.init(allocator, 31, 32, 32);
    defer lsa.deinit();

    var info = liveness.LivenessInfo.init(allocator);
    defer info.deinit();

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .float);
    const v2 = machinst.VReg.new(2, .vector);

    // All overlapping but different classes
    try info.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 10,
        .reg_class = .int,
    });

    try info.addRange(.{
        .vreg = v1,
        .start_inst = 0,
        .end_inst = 10,
        .reg_class = .float,
    });

    try info.addRange(.{
        .vreg = v2,
        .start_inst = 0,
        .end_inst = 10,
        .reg_class = .vector,
    });

    var result = try lsa.allocate(&info);
    defer result.deinit();

    // All should be allocated
    const p0 = result.getPhysReg(v0);
    const p1 = result.getPhysReg(v1);
    const p2 = result.getPhysReg(v2);

    try std.testing.expect(p0 != null);
    try std.testing.expect(p1 != null);
    try std.testing.expect(p2 != null);

    // Should have correct classes
    try std.testing.expectEqual(machinst.RegClass.int, p0.?.class);
    try std.testing.expectEqual(machinst.RegClass.float, p1.?.class);
    try std.testing.expectEqual(machinst.RegClass.vector, p2.?.class);

    // Can all use index 0 (different register files)
    try std.testing.expectEqual(@as(u32, 0), p0.?.index);
    try std.testing.expectEqual(@as(u32, 0), p1.?.index);
    try std.testing.expectEqual(@as(u32, 0), p2.?.index);
}

test "LinearScanAllocator out of registers error" {
    const allocator = std.testing.allocator;

    var lsa = try LinearScanAllocator.init(allocator, 2, 2, 2); // Only 2 int regs
    defer lsa.deinit();

    var info = liveness.LivenessInfo.init(allocator);
    defer info.deinit();

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .int);
    const v2 = machinst.VReg.new(2, .int);

    // Three overlapping int ranges - more than 2 available regs
    try info.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 10,
        .reg_class = .int,
    });

    try info.addRange(.{
        .vreg = v1,
        .start_inst = 0,
        .end_inst = 10,
        .reg_class = .int,
    });

    try info.addRange(.{
        .vreg = v2,
        .start_inst = 0,
        .end_inst = 10,
        .reg_class = .int,
    });

    // Should return OutOfRegisters error
    const result_or_err = lsa.allocate(&info);
    try std.testing.expectError(error.OutOfRegisters, result_or_err);
}
