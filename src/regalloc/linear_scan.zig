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

const reg_map_len: usize = 64;
const invalid_reg_idx: u8 = 0xFF;
const spill_size_int: u32 = 8;
const spill_size_vec: u32 = 16;

fn initRegIndex(map: *[reg_map_len]u8, regs: []const machinst.PReg) void {
    for (regs, 0..) |reg, idx| {
        const hw = reg.hwEnc();
        std.debug.assert(map[hw] == invalid_reg_idx);
        map[hw] = @intCast(idx);
    }
}

fn spillSlotSize(reg_class: machinst.RegClass) u32 {
    return switch (reg_class) {
        .int, .float => spill_size_int,
        .vector => spill_size_vec,
    };
}

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
        return self.vreg_to_preg.get(vreg.index());
    }

    /// Assign a physical register to a virtual register
    pub fn assign(self: *RegAllocResult, vreg: machinst.VReg, preg: machinst.PReg) !void {
        try self.vreg_to_preg.put(vreg.index(), preg);
    }

    /// Clear any physical register assignment for a virtual register.
    pub fn clearReg(self: *RegAllocResult, vreg: machinst.VReg) void {
        _ = self.vreg_to_preg.remove(vreg.index());
    }

    /// Get the spill slot for a virtual register
    pub fn getSpillSlot(self: *RegAllocResult, vreg: machinst.VReg) ?SpillSlot {
        return self.vreg_to_spill.get(vreg.index());
    }

    /// Assign a spill slot to a virtual register
    pub fn assignSpillSlot(self: *RegAllocResult, vreg: machinst.VReg, slot: SpillSlot) !void {
        try self.vreg_to_spill.put(vreg.index(), slot);
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

    /// Allocatable physical registers per class
    int_regs: std.ArrayList(machinst.PReg),
    float_regs: std.ArrayList(machinst.PReg),
    vector_regs: std.ArrayList(machinst.PReg),

    /// Map from hardware register encoding to index in allocatable list
    int_reg_index: [reg_map_len]u8,
    float_reg_index: [reg_map_len]u8,
    vector_reg_index: [reg_map_len]u8,

    /// Next available spill slot offset (in bytes)
    next_spill_offset: u32,

    /// Free spill slots that can be reused
    /// Stores offsets of slots that were allocated but are no longer in use
    free_spill_slots_8: std.ArrayList(u32),
    free_spill_slots_16: std.ArrayList(u32),

    /// Register allocation hints: preferred physical register for each virtual register
    /// Used to improve allocation quality by preferring certain registers when available
    hints: std.AutoHashMap(u32, machinst.PReg),

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
        var int_regs = std.ArrayList(machinst.PReg){};
        defer int_regs.deinit(allocator);
        var float_regs = std.ArrayList(machinst.PReg){};
        defer float_regs.deinit(allocator);
        var vector_regs = std.ArrayList(machinst.PReg){};
        defer vector_regs.deinit(allocator);

        var i: u32 = 0;
        while (i < num_int_regs) : (i += 1) {
            try int_regs.append(allocator, machinst.PReg.new(.int, @intCast(i)));
        }

        i = 0;
        while (i < num_float_regs) : (i += 1) {
            try float_regs.append(allocator, machinst.PReg.new(.float, @intCast(i)));
        }

        i = 0;
        while (i < num_vector_regs) : (i += 1) {
            try vector_regs.append(allocator, machinst.PReg.new(.vector, @intCast(i)));
        }

        return initWithRegs(allocator, int_regs.items, float_regs.items, vector_regs.items);
    }

    /// Initialize the allocator with explicit allocatable registers per class.
    pub fn initWithRegs(
        allocator: std.mem.Allocator,
        int_regs: []const machinst.PReg,
        float_regs: []const machinst.PReg,
        vector_regs: []const machinst.PReg,
    ) !LinearScanAllocator {
        var free_int = try std.DynamicBitSet.initFull(allocator, int_regs.len);
        errdefer free_int.deinit();

        var free_float = try std.DynamicBitSet.initFull(allocator, float_regs.len);
        errdefer free_float.deinit();

        var free_vector = try std.DynamicBitSet.initFull(allocator, vector_regs.len);
        errdefer free_vector.deinit();

        var int_list = std.ArrayList(machinst.PReg){};
        errdefer int_list.deinit(allocator);
        try int_list.appendSlice(allocator, int_regs);

        var float_list = std.ArrayList(machinst.PReg){};
        errdefer float_list.deinit(allocator);
        try float_list.appendSlice(allocator, float_regs);

        var vector_list = std.ArrayList(machinst.PReg){};
        errdefer vector_list.deinit(allocator);
        try vector_list.appendSlice(allocator, vector_regs);

        var int_reg_index = [_]u8{invalid_reg_idx} ** reg_map_len;
        var float_reg_index = [_]u8{invalid_reg_idx} ** reg_map_len;
        var vector_reg_index = [_]u8{invalid_reg_idx} ** reg_map_len;

        initRegIndex(&int_reg_index, int_list.items);
        initRegIndex(&float_reg_index, float_list.items);
        initRegIndex(&vector_reg_index, vector_list.items);

        return .{
            .active = std.ArrayList(liveness.LiveRange){},
            .inactive = std.ArrayList(liveness.LiveRange){},
            .free_int_regs = free_int,
            .free_float_regs = free_float,
            .free_vector_regs = free_vector,
            .int_regs = int_list,
            .float_regs = float_list,
            .vector_regs = vector_list,
            .int_reg_index = int_reg_index,
            .float_reg_index = float_reg_index,
            .vector_reg_index = vector_reg_index,
            .next_spill_offset = 0,
            .free_spill_slots_8 = std.ArrayList(u32){},
            .free_spill_slots_16 = std.ArrayList(u32){},
            .hints = std.AutoHashMap(u32, machinst.PReg).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LinearScanAllocator) void {
        self.active.deinit(self.allocator);
        self.inactive.deinit(self.allocator);
        self.free_int_regs.deinit();
        self.free_float_regs.deinit();
        self.free_vector_regs.deinit();
        self.int_regs.deinit(self.allocator);
        self.float_regs.deinit(self.allocator);
        self.vector_regs.deinit(self.allocator);
        self.free_spill_slots_8.deinit(self.allocator);
        self.free_spill_slots_16.deinit(self.allocator);
        self.hints.deinit();
    }

    fn regIndex(self: *LinearScanAllocator, preg: machinst.PReg) ?u32 {
        const hw = preg.hwEnc();
        const idx = switch (preg.class()) {
            .int => self.int_reg_index[hw],
            .float => self.float_reg_index[hw],
            .vector => self.vector_reg_index[hw],
        };
        if (idx == invalid_reg_idx) return null;
        return idx;
    }

    fn requireRegIndex(self: *LinearScanAllocator, preg: machinst.PReg) !u32 {
        return self.regIndex(preg) orelse error.InvalidPhysReg;
    }

    fn regAt(self: *LinearScanAllocator, reg_class: machinst.RegClass, idx: u32) machinst.PReg {
        return switch (reg_class) {
            .int => self.int_regs.items[idx],
            .float => self.float_regs.items[idx],
            .vector => self.vector_regs.items[idx],
        };
    }

    fn freeSpillSlots(self: *LinearScanAllocator, reg_class: machinst.RegClass) *std.ArrayList(u32) {
        return switch (reg_class) {
            .int, .float => &self.free_spill_slots_8,
            .vector => &self.free_spill_slots_16,
        };
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
                    const reg_idx = try self.requireRegIndex(preg);
                    free_regs.unset(reg_idx);
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
                // This interval has ended - free its register or spill slot
                if (result.getPhysReg(range.vreg)) |preg| {
                    // Had a register - mark it as free
                    const free_regs = self.getFreeRegs(range.reg_class);
                    const reg_idx = try self.requireRegIndex(preg);
                    free_regs.set(reg_idx);
                } else if (result.getSpillSlot(range.vreg)) |slot| {
                    // Was spilled - free the spill slot for reuse
                    try self.freeSpillSlot(slot, range.reg_class);
                }

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

        // Check hint first if one exists
        if (self.hints.get(range.vreg.index())) |hint| {
            if (hint.class() == range.reg_class) {
                if (self.regIndex(hint)) |reg_idx| {
                    if (free_regs.isSet(reg_idx)) {
                        // Hint is available! Use it
                        try result.assign(range.vreg, hint);
                        free_regs.unset(reg_idx);
                        try self.active.append(self.allocator, range);
                        return hint;
                    }
                }
            }
        }

        // No hint or hint unavailable - find first free register
        var reg_idx: u32 = 0;
        const num_regs = self.getNumRegs(range.reg_class);
        while (reg_idx < num_regs) : (reg_idx += 1) {
            if (free_regs.isSet(reg_idx)) {
                // Found a free register!
                const preg = self.regAt(range.reg_class, reg_idx);

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
        const reg_idx = try self.requireRegIndex(preg);
        free_regs.set(reg_idx);

        // Allocate a spill slot for the spilled vreg
        result.clearReg(spill_range.vreg);
        const spill_slot = try self.allocateSpillSlot(spill_range.reg_class);
        try result.assignSpillSlot(spill_range.vreg, spill_slot);

        return preg;
    }

    /// Allocate a spill slot on the stack.
    ///
    /// Returns a SpillSlot with an available stack offset.
    /// Reuses freed slots when possible, otherwise allocates a new one.
    /// Spill slots are allocated in 8-byte increments to maintain alignment.
    fn allocateSpillSlot(self: *LinearScanAllocator, reg_class: machinst.RegClass) !SpillSlot {
        const free_slots = self.freeSpillSlots(reg_class);
        if (free_slots.items.len > 0) {
            const offset = free_slots.pop() orelse unreachable;
            return SpillSlot.init(offset);
        }

        const size = spillSlotSize(reg_class);
        const aligned_offset = std.mem.alignForward(u32, self.next_spill_offset, size);
        const slot = SpillSlot.init(aligned_offset);
        self.next_spill_offset = aligned_offset + size;
        return slot;
    }

    /// Free a spill slot for reuse.
    ///
    /// Marks the slot as available for future allocations.
    /// Called when a spilled vreg's live range ends.
    fn freeSpillSlot(self: *LinearScanAllocator, slot: SpillSlot, reg_class: machinst.RegClass) !void {
        try self.freeSpillSlots(reg_class).append(self.allocator, slot.offset);
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
            .int => @intCast(self.int_regs.items.len),
            .float => @intCast(self.float_regs.items.len),
            .vector => @intCast(self.vector_regs.items.len),
        };
    }

    /// Set a register allocation hint for a virtual register.
    /// The allocator will prefer the hinted physical register if it's available.
    pub fn setHint(self: *LinearScanAllocator, vreg: machinst.VReg, preg: machinst.PReg) !void {
        try self.hints.put(vreg.index(), preg);
    }

    /// Get the hint for a virtual register, if one exists.
    pub fn getHint(self: *LinearScanAllocator, vreg: machinst.VReg) ?machinst.PReg {
        return self.hints.get(vreg.index());
    }
};

test "LinearScanAllocator init/deinit" {
    const allocator = std.testing.allocator;

    var lsa = try LinearScanAllocator.init(allocator, 31, 32, 32);
    defer lsa.deinit();

    try std.testing.expectEqual(@as(usize, 31), lsa.int_regs.items.len);
    try std.testing.expectEqual(@as(usize, 32), lsa.float_regs.items.len);
    try std.testing.expectEqual(@as(usize, 32), lsa.vector_regs.items.len);

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
    try std.testing.expectEqual(preg0.index(), assigned.?.index());
    try std.testing.expectEqual(preg0.class(), assigned.?.class());
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
    try std.testing.expectEqual(machinst.RegClass.int, p0.?.class());
    try std.testing.expectEqual(machinst.RegClass.int, p1.?.class());
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
    try std.testing.expect(p0.?.index() != p1.?.index());
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
    try std.testing.expect(p0.?.index() != p1.?.index());

    // v2 should reuse one of the registers from v0 or v1
    try std.testing.expect(p2.?.index() == p0.?.index() or p2.?.index() == p1.?.index());
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
    try std.testing.expectEqual(machinst.RegClass.int, p0.?.class());
    try std.testing.expectEqual(machinst.RegClass.float, p1.?.class());
    try std.testing.expectEqual(machinst.RegClass.vector, p2.?.class());

    // Can all use index 0 (different register files)
    try std.testing.expectEqual(@as(u6, 0), p0.?.hwEnc());
    try std.testing.expectEqual(@as(u6, 0), p1.?.hwEnc());
    try std.testing.expectEqual(@as(u6, 0), p2.?.hwEnc());
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

test "LinearScanAllocator register hints" {
    const allocator = std.testing.allocator;

    var lsa = try LinearScanAllocator.init(allocator, 31, 32, 32);
    defer lsa.deinit();

    var info = liveness.LivenessInfo.init(allocator);
    defer info.deinit();

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .int);

    // Non-overlapping ranges
    try info.addRange(.{
        .vreg = v0,
        .start_inst = 0,
        .end_inst = 10,
        .reg_class = .int,
    });

    try info.addRange(.{
        .vreg = v1,
        .start_inst = 15,
        .end_inst = 25,
        .reg_class = .int,
    });

    // Set hint for v1 to use register X5
    const hint_preg = machinst.PReg.new(.int, 5);
    try lsa.setHint(v1, hint_preg);

    // Verify hint was set
    const retrieved_hint = lsa.getHint(v1);
    try std.testing.expect(retrieved_hint != null);
    try std.testing.expectEqual(hint_preg.index(), retrieved_hint.?.index());
    try std.testing.expectEqual(hint_preg.class(), retrieved_hint.?.class());

    // Allocate - v1 should get hint register X5
    var result = try lsa.allocate(&info);
    defer result.deinit();

    const v1_preg = result.getPhysReg(v1);
    try std.testing.expect(v1_preg != null);
    try std.testing.expectEqual(@as(u32, 5), v1_preg.?.index());
    try std.testing.expectEqual(machinst.RegClass.int, v1_preg.?.class());
}
