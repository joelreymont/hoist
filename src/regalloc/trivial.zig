//! Trivial register allocator with spilling support.
//!
//! Simple linear-scan allocator that:
//! - Tracks register liveness
//! - Allocates physical registers when available
//! - Spills to stack when out of registers
//! - Reuses registers after values die
//!
//! Algorithm:
//! 1. Compute live ranges for all vregs
//! 2. For each instruction:
//!    - Expire old ranges (free registers for dead values)
//!    - Allocate registers for defs
//!    - If out of registers, spill to stack
//!
//! This is still simplified compared to regalloc2:
//! - No register hints
//! - No move coalescing
//! - Simple spill cost heuristics
//! - No live range splitting

const std = @import("std");
const reg_mod = @import("../machinst/reg.zig");

pub const VReg = reg_mod.VReg;
pub const PReg = reg_mod.PReg;
pub const RegClass = reg_mod.RegClass;

/// Spill slot identifier.
pub const SpillSlot = struct {
    index: u32,

    pub fn new(index: u32) SpillSlot {
        return .{ .index = index };
    }

    pub fn eql(self: SpillSlot, other: SpillSlot) bool {
        return self.index == other.index;
    }

    pub fn hash(self: SpillSlot) u64 {
        return @as(u64, self.index);
    }
};

/// Allocation result - either a physical register or a spill slot.
pub const Allocation = union(enum) {
    reg: PReg,
    spill: SpillSlot,

    pub fn isReg(self: Allocation) bool {
        return self == .reg;
    }

    pub fn isSpill(self: Allocation) bool {
        return self == .spill;
    }
};

/// Liveness information for a virtual register.
const LiveRange = struct {
    vreg: VReg,
    /// First instruction where this vreg is defined.
    start: u32,
    /// Last instruction where this vreg is used.
    end: u32,
};

/// Pair of adjacent spill slots for STP optimization.
const AdjacentSlots = struct {
    first: SpillSlot,
    second: SpillSlot,
};

/// Trivial linear-scan register allocator with spilling support.
pub const TrivialAllocator = struct {
    /// Mapping from virtual register to allocation (physical reg or spill slot).
    vreg_to_allocation: std.AutoHashMap(VReg, Allocation),

    /// Live ranges for all virtual registers.
    live_ranges: std.ArrayList(LiveRange),

    /// Currently allocated physical registers (vreg currently in each preg).
    /// Index is hardware encoding, value is VReg or null if free.
    int_regs: [30]?VReg, // x0-x29
    float_regs: [32]?VReg, // v0-v31

    /// Next free spill slot index.
    next_spill_slot: u32,

    /// Previous spill slot allocated (for adjacency detection).
    prev_spill_slot: ?SpillSlot,

    /// Tracks adjacent spill slot pairs for STP coalescing.
    /// Maps first slot to its adjacent pair.
    adjacent_spill_slots: std.AutoHashMap(SpillSlot, AdjacentSlots),

    /// Allocator.
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .vreg_to_allocation = std.AutoHashMap(VReg, Allocation).init(allocator),
            .live_ranges = .{},
            .int_regs = [_]?VReg{null} ** 30,
            .float_regs = [_]?VReg{null} ** 32,
            .next_spill_slot = 0,
            .prev_spill_slot = null,
            .adjacent_spill_slots = std.AutoHashMap(SpillSlot, AdjacentSlots).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.vreg_to_allocation.deinit();
        self.live_ranges.deinit(self.allocator);
        self.adjacent_spill_slots.deinit();
    }

    /// Free physical registers for vregs whose live ranges have ended.
    fn expireOldRanges(self: *Self, current_pos: u32) void {
        // Free int registers
        for (&self.int_regs) |*slot| {
            if (slot.*) |vreg| {
                // Find live range for this vreg
                for (self.live_ranges.items) |lr| {
                    if (lr.vreg.bits == vreg.bits and lr.end < current_pos) {
                        slot.* = null;
                        break;
                    }
                }
            }
        }

        // Free float/vector registers
        for (&self.float_regs) |*slot| {
            if (slot.*) |vreg| {
                for (self.live_ranges.items) |lr| {
                    if (lr.vreg.bits == vreg.bits and lr.end < current_pos) {
                        slot.* = null;
                        break;
                    }
                }
            }
        }
    }

    /// Allocate a physical register or spill slot for a virtual register.
    /// Returns the allocation (reg or spill).
    pub fn allocate(self: *Self, vreg: VReg, current_pos: u32) !Allocation {
        // Check if already allocated
        if (self.vreg_to_allocation.get(vreg)) |allocation| {
            return allocation;
        }

        // Expire old ranges to free up registers
        self.expireOldRanges(current_pos);

        // Try to allocate a physical register
        const allocation = switch (vreg.class()) {
            .int => blk: {
                // Find free int register
                for (&self.int_regs, 0..) |*slot, idx| {
                    if (slot.* == null) {
                        slot.* = vreg;
                        const preg = PReg.new(.int, @intCast(idx));
                        break :blk Allocation{ .reg = preg };
                    }
                }
                // Out of registers - spill
                const spill = SpillSlot.new(self.next_spill_slot);
                self.next_spill_slot += 1;

                // Check if adjacent to previous spill (8-byte aligned slots)
                if (self.prev_spill_slot) |prev| {
                    if (prev.index + 1 == spill.index) {
                        // Adjacent slots - mark for STP coalescing
                        try self.adjacent_spill_slots.put(prev, .{
                            .first = prev,
                            .second = spill,
                        });
                    }
                }
                self.prev_spill_slot = spill;

                break :blk Allocation{ .spill = spill };
            },
            .float, .vector => blk: {
                // Find free float register (vector aliases with float)
                for (&self.float_regs, 0..) |*slot, idx| {
                    if (slot.* == null) {
                        slot.* = vreg;
                        const preg = PReg.new(vreg.class(), @intCast(idx));
                        break :blk Allocation{ .reg = preg };
                    }
                }
                // Out of registers - spill
                const spill = SpillSlot.new(self.next_spill_slot);
                self.next_spill_slot += 1;

                // Check if adjacent to previous spill (8-byte aligned slots)
                if (self.prev_spill_slot) |prev| {
                    if (prev.index + 1 == spill.index) {
                        // Adjacent slots - mark for STP coalescing
                        try self.adjacent_spill_slots.put(prev, .{
                            .first = prev,
                            .second = spill,
                        });
                    }
                }
                self.prev_spill_slot = spill;

                break :blk Allocation{ .spill = spill };
            },
        };

        // Store mapping
        try self.vreg_to_allocation.put(vreg, allocation);
        return allocation;
    }

    /// Get the allocation for a virtual register.
    /// Returns null if not yet allocated.
    pub fn getAllocation(self: *const Self, vreg: VReg) ?Allocation {
        return self.vreg_to_allocation.get(vreg);
    }

    /// Record a live range for a vreg.
    /// Used during liveness analysis.
    pub fn recordLiveRange(self: *Self, vreg: VReg, start: u32, end: u32) !void {
        try self.live_ranges.append(self.allocator, .{ .vreg = vreg, .start = start, .end = end });
    }

    /// Get the number of spill slots allocated.
    pub fn spillSlotCount(self: *const Self) u32 {
        return self.next_spill_slot;
    }
};

test "TrivialAllocator basic allocation" {
    const testing = std.testing;

    var allocator = TrivialAllocator.init(testing.allocator);
    defer allocator.deinit();

    // Allocate integer registers
    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);

    // Record live ranges
    try allocator.recordLiveRange(v0, 0, 2);
    try allocator.recordLiveRange(v1, 1, 3);

    const a0 = try allocator.allocate(v0, 0);
    const a1 = try allocator.allocate(v1, 1);

    // Should both get registers
    try testing.expect(a0.isReg());
    try testing.expect(a1.isReg());
    try testing.expectEqual(RegClass.int, a0.reg.class());
    try testing.expectEqual(RegClass.int, a1.reg.class());
    try testing.expectEqual(@as(u6, 0), a0.reg.hwEnc());
    try testing.expectEqual(@as(u6, 1), a1.reg.hwEnc());

    // Allocating same vreg again should return same allocation
    const a0_again = try allocator.allocate(v0, 0);
    try testing.expect(a0_again.isReg());
    try testing.expectEqual(a0.reg.hwEnc(), a0_again.reg.hwEnc());
}

test "TrivialAllocator register reuse after expiry" {
    const testing = std.testing;

    var allocator = TrivialAllocator.init(testing.allocator);
    defer allocator.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);

    // v0 dies at position 2, v1 starts at position 3
    try allocator.recordLiveRange(v0, 0, 2);
    try allocator.recordLiveRange(v1, 3, 5);

    // Allocate v0 at position 0
    const a0 = try allocator.allocate(v0, 0);
    try testing.expect(a0.isReg());
    try testing.expectEqual(@as(u6, 0), a0.reg.hwEnc());

    // Allocate v1 at position 3 (after v0 dies)
    const a1 = try allocator.allocate(v1, 3);
    try testing.expect(a1.isReg());
    // Should reuse x0 since v0 is dead
    try testing.expectEqual(@as(u6, 0), a1.reg.hwEnc());
}

test "TrivialAllocator spilling when out of registers" {
    const testing = std.testing;

    var allocator = TrivialAllocator.init(testing.allocator);
    defer allocator.deinit();

    // Allocate all 30 int registers
    var vregs: [30]VReg = undefined;
    for (0..30) |i| {
        vregs[i] = VReg.new(@intCast(i), .int);
        try allocator.recordLiveRange(vregs[i], 0, 10);
        const alloc = try allocator.allocate(vregs[i], 0);
        try testing.expect(alloc.isReg());
    }

    // 31st register should spill
    const v_spill = VReg.new(30, .int);
    try allocator.recordLiveRange(v_spill, 0, 10);
    const alloc_spill = try allocator.allocate(v_spill, 0);
    try testing.expect(alloc_spill.isSpill());
    try testing.expectEqual(@as(u32, 0), alloc_spill.spill.index);

    // Verify spill slot count
    try testing.expectEqual(@as(u32, 1), allocator.spillSlotCount());
}

test "TrivialAllocator getAllocation" {
    const testing = std.testing;

    var allocator = TrivialAllocator.init(testing.allocator);
    defer allocator.deinit();

    const v0 = VReg.new(0, .int);
    try allocator.recordLiveRange(v0, 0, 2);

    // Before allocation, should return null
    try testing.expectEqual(@as(?Allocation, null), allocator.getAllocation(v0));

    // After allocation, should return allocation
    const alloc = try allocator.allocate(v0, 0);
    const retrieved = allocator.getAllocation(v0).?;
    try testing.expect(retrieved.isReg());
    try testing.expectEqual(alloc.reg.hwEnc(), retrieved.reg.hwEnc());
}
