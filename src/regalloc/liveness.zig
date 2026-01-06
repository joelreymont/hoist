//! Liveness analysis for register allocation.
//!
//! This module provides data structures and algorithms for computing live ranges
//! of virtual registers, which is essential for register allocation.

const std = @import("std");
const machinst = @import("../machinst/machinst.zig");

/// A live range represents the span of instructions where a virtual register is live.
///
/// A virtual register is considered live between its definition point and its last use.
/// The live range is represented as an interval [start_inst, end_inst] where both
/// endpoints are inclusive instruction indices.
pub const LiveRange = struct {
    /// The virtual register this range belongs to
    vreg: machinst.VReg,

    /// First instruction where this vreg is live (inclusive)
    /// This is typically the instruction that defines the vreg
    start_inst: u32,

    /// Last instruction where this vreg is live (inclusive)
    /// This is typically the last instruction that uses the vreg
    end_inst: u32,

    /// Register class this vreg belongs to (int, float, vector)
    reg_class: machinst.RegClass,

    /// Check if this range overlaps with another range
    pub fn overlaps(self: LiveRange, other: LiveRange) bool {
        return self.start_inst <= other.end_inst and other.start_inst <= self.end_inst;
    }

    /// Check if a given instruction index is within this live range
    pub fn contains(self: LiveRange, inst_idx: u32) bool {
        return inst_idx >= self.start_inst and inst_idx <= self.end_inst;
    }

    /// Return the length of this live range (number of instructions)
    pub fn length(self: LiveRange) u32 {
        return self.end_inst - self.start_inst + 1;
    }
};

/// Container for liveness information for all virtual registers in a function.
///
/// This tracks the live ranges of all vregs and provides efficient lookup
/// from vreg to its corresponding live range.
pub const LivenessInfo = struct {
    /// All live ranges in the function
    ranges: std.ArrayList(LiveRange),

    /// Map from vreg index to its live range index in the ranges array
    /// This enables O(1) lookup of a vreg's live range
    vreg_to_range: std.AutoHashMap(u32, u32),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LivenessInfo {
        return .{
            .ranges = std.ArrayList(LiveRange).init(allocator),
            .vreg_to_range = std.AutoHashMap(u32, u32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LivenessInfo) void {
        self.ranges.deinit();
        self.vreg_to_range.deinit();
    }

    /// Add a live range for a virtual register
    pub fn addRange(self: *LivenessInfo, range: LiveRange) !void {
        const range_idx: u32 = @intCast(self.ranges.items.len);
        try self.ranges.append(self.allocator, range);
        try self.vreg_to_range.put(range.vreg.index, range_idx);
    }

    /// Get the live range for a given virtual register
    /// Returns null if the vreg has no recorded live range
    pub fn getRange(self: *LivenessInfo, vreg: machinst.VReg) ?*const LiveRange {
        const range_idx = self.vreg_to_range.get(vreg.index) orelse return null;
        return &self.ranges.items[range_idx];
    }

    /// Get all live ranges, sorted by start instruction
    /// This is useful for linear scan register allocation
    pub fn getRangesSortedByStart(self: *LivenessInfo) ![]LiveRange {
        const items = try self.allocator.dupe(LiveRange, self.ranges.items);
        std.mem.sort(LiveRange, items, {}, struct {
            fn lessThan(_: void, a: LiveRange, b: LiveRange) bool {
                return a.start_inst < b.start_inst;
            }
        }.lessThan);
        return items;
    }

    /// Check if two vregs interfere (have overlapping live ranges)
    pub fn interfere(self: *LivenessInfo, vreg1: machinst.VReg, vreg2: machinst.VReg) bool {
        const range1 = self.getRange(vreg1) orelse return false;
        const range2 = self.getRange(vreg2) orelse return false;
        return range1.overlaps(range2.*);
    }
};

/// Helper to track per-vreg information during liveness computation
const VRegInfo = struct {
    first_def: ?u32,
    last_use: u32,
    reg_class: machinst.RegClass,
};

/// Compute liveness information for all virtual registers in a function.
///
/// This performs a simple intra-block forward scan:
/// - On first definition of a vreg, record start_inst
/// - On each use, update end_inst
///
/// The Inst type must have methods:
/// - getDefs(allocator) ![]machinst.VReg - returns defined vregs
/// - getUses(allocator) ![]machinst.VReg - returns used vregs
///
/// Note: This is a simplified version that doesn't handle control flow.
/// A full implementation would need CFG-aware dataflow analysis.
pub fn computeLiveness(
    comptime Inst: type,
    insns: []const Inst,
    allocator: std.mem.Allocator,
) !LivenessInfo {
    var info = LivenessInfo.init(allocator);
    errdefer info.deinit();

    // Track per-vreg information during the scan
    var vreg_info = std.AutoHashMap(u32, VRegInfo).init(allocator);
    defer vreg_info.deinit();

    // Forward scan through instructions
    for (insns, 0..) |inst, idx| {
        const inst_idx: u32 = @intCast(idx);

        // Process definitions - mark start of live range
        const defs = try inst.getDefs(allocator);
        defer allocator.free(defs);

        for (defs) |vreg| {
            const entry = try vreg_info.getOrPut(vreg.index);
            if (!entry.found_existing) {
                entry.value_ptr.* = .{
                    .first_def = inst_idx,
                    .last_use = inst_idx,
                    .reg_class = vreg.class,
                };
            } else {
                // Multiple definitions - this is unusual but possible with phi nodes
                // Keep the first definition
                if (entry.value_ptr.first_def == null) {
                    entry.value_ptr.first_def = inst_idx;
                }
            }
        }

        // Process uses - extend live range
        const uses = try inst.getUses(allocator);
        defer allocator.free(uses);

        for (uses) |vreg| {
            const entry = try vreg_info.getOrPut(vreg.index);
            if (!entry.found_existing) {
                // Use before def - this can happen with function parameters
                // Treat the use as both the start and current end
                entry.value_ptr.* = .{
                    .first_def = null, // No definition yet
                    .last_use = inst_idx,
                    .reg_class = vreg.class,
                };
            } else {
                // Update last use
                entry.value_ptr.last_use = inst_idx;
            }
        }
    }

    // Convert vreg_info to live ranges
    var iter = vreg_info.iterator();
    while (iter.next()) |entry| {
        const vreg_idx = entry.key_ptr.*;
        const vinfo = entry.value_ptr.*;

        // Start is either first definition or first use (for parameters)
        const start = vinfo.first_def orelse 0;

        try info.addRange(.{
            .vreg = machinst.VReg.new(vreg_idx, vinfo.reg_class),
            .start_inst = start,
            .end_inst = vinfo.last_use,
            .reg_class = vinfo.reg_class,
        });
    }

    return info;
}

test "LiveRange.overlaps" {
    const range1 = LiveRange{
        .vreg = machinst.VReg.new(0, .int),
        .start_inst = 10,
        .end_inst = 20,
        .reg_class = .int,
    };

    const range2 = LiveRange{
        .vreg = machinst.VReg.new(1, .int),
        .start_inst = 15,
        .end_inst = 25,
        .reg_class = .int,
    };

    const range3 = LiveRange{
        .vreg = machinst.VReg.new(2, .int),
        .start_inst = 21,
        .end_inst = 30,
        .reg_class = .int,
    };

    try std.testing.expect(range1.overlaps(range2));
    try std.testing.expect(range2.overlaps(range1));
    try std.testing.expect(!range1.overlaps(range3));
    try std.testing.expect(!range3.overlaps(range1));
}

test "LiveRange.contains" {
    const range = LiveRange{
        .vreg = machinst.VReg.new(0, .int),
        .start_inst = 10,
        .end_inst = 20,
        .reg_class = .int,
    };

    try std.testing.expect(range.contains(10));
    try std.testing.expect(range.contains(15));
    try std.testing.expect(range.contains(20));
    try std.testing.expect(!range.contains(9));
    try std.testing.expect(!range.contains(21));
}

test "LivenessInfo basic operations" {
    const allocator = std.testing.allocator;
    var info = LivenessInfo.init(allocator);
    defer info.deinit();

    const vreg0 = machinst.VReg.new(0, .int);
    const vreg1 = machinst.VReg.new(1, .int);

    try info.addRange(.{
        .vreg = vreg0,
        .start_inst = 0,
        .end_inst = 10,
        .reg_class = .int,
    });

    try info.addRange(.{
        .vreg = vreg1,
        .start_inst = 5,
        .end_inst = 15,
        .reg_class = .int,
    });

    const range0 = info.getRange(vreg0);
    try std.testing.expect(range0 != null);
    try std.testing.expectEqual(@as(u32, 0), range0.?.start_inst);
    try std.testing.expectEqual(@as(u32, 10), range0.?.end_inst);

    try std.testing.expect(info.interfere(vreg0, vreg1));
}
