//! Liveness analysis for register allocation.
//!
//! This module provides data structures and algorithms for computing live ranges
//! of virtual registers, which is essential for register allocation.

const std = @import("std");
const machinst = @import("../machinst/machinst.zig");
const cfg_mod = @import("../ir/cfg.zig");

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
            .ranges = std.ArrayList(LiveRange){},
            .vreg_to_range = std.AutoHashMap(u32, u32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LivenessInfo) void {
        self.ranges.deinit(self.allocator);
        self.vreg_to_range.deinit();
    }

    /// Add a live range for a virtual register
    pub fn addRange(self: *LivenessInfo, range: LiveRange) !void {
        const range_idx: u32 = @intCast(self.ranges.items.len);
        try self.ranges.append(self.allocator, range);
        try self.vreg_to_range.put(range.vreg.index(), range_idx);
    }

    /// Get the live range for a given virtual register
    /// Returns null if the vreg has no recorded live range
    pub fn getRange(self: *LivenessInfo, vreg: machinst.VReg) ?*const LiveRange {
        const range_idx = self.vreg_to_range.get(vreg.index()) orelse return null;
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
            const entry = try vreg_info.getOrPut(vreg.index());
            if (!entry.found_existing) {
                entry.value_ptr.* = .{
                    .first_def = inst_idx,
                    .last_use = inst_idx,
                    .reg_class = vreg.class(),
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
            const entry = try vreg_info.getOrPut(vreg.index());
            if (!entry.found_existing) {
                // Use before def - this can happen with function parameters
                // Treat the use as both the start and current end
                entry.value_ptr.* = .{
                    .first_def = null, // No definition yet
                    .last_use = inst_idx,
                    .reg_class = vreg.class(),
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

/// Compute liveness information using control flow graph aware dataflow analysis.
///
/// This performs a backward dataflow analysis on the CFG:
/// - Computes live_out[B] = ∪(live_in[all successors including exception_successors])
/// - Computes live_in[B] = uses[B] ∪ (live_out[B] - defs[B])
/// - Iterates until a fixed point is reached
///
/// This version properly handles exception edges from try_call instructions,
/// ensuring that values live at the try_call are propagated to exception
/// landing pad blocks. Exception edges transfer liveness just like normal edges.
///
/// The Inst type must have methods:
/// - getDefs(allocator) ![]machinst.VReg - returns defined vregs
/// - getUses(allocator) ![]machinst.VReg - returns used vregs
pub fn computeLivenessWithCFG(
    comptime Inst: type,
    blocks: []const cfg_mod.CFGNode,
    block_insns: std.AutoHashMap(u32, []const Inst),
    allocator: std.mem.Allocator,
) !LivenessInfo {
    var info = LivenessInfo.init(allocator);
    errdefer info.deinit();

    // Track per-vreg information for all blocks
    var block_live_in = std.AutoHashMap(u32, std.AutoHashMap(u32, void)).init(allocator);
    defer {
        var it = block_live_in.valueIterator();
        while (it.next()) |set| {
            set.deinit();
        }
        block_live_in.deinit();
    }

    var block_live_out = std.AutoHashMap(u32, std.AutoHashMap(u32, void)).init(allocator);
    defer {
        var it = block_live_out.valueIterator();
        while (it.next()) |set| {
            set.deinit();
        }
        block_live_out.deinit();
    }

    // Initialize live_in and live_out sets for all blocks
    for (0..blocks.len) |block_idx| {
        const block_id: u32 = @intCast(block_idx);
        const live_in_set = std.AutoHashMap(u32, void).init(allocator);
        const live_out_set = std.AutoHashMap(u32, void).init(allocator);
        try block_live_in.put(block_id, live_in_set);
        try block_live_out.put(block_id, live_out_set);
    }

    // Iteratively compute liveness until fixed point
    var changed = true;
    while (changed) {
        changed = false;

        // Process blocks in reverse order (backward analysis)
        var block_idx: i32 = @intCast(blocks.len - 1);
        while (block_idx >= 0) : (block_idx -= 1) {
            const block_id: u32 = @intCast(block_idx);
            const block = &blocks[@intCast(block_idx)];

            // Compute live_out[B] = ∪(live_in[normal_successors ∪ exception_successors])
            var new_live_out = std.AutoHashMap(u32, void).init(allocator);
            defer new_live_out.deinit();

            // Add live_in from all normal successors
            var succ_iter = block.successors.keyIterator();
            while (succ_iter.next()) |succ_block| {
                const succ_id = succ_block.toIndex();
                if (block_live_in.get(@intCast(succ_id))) |succ_live_in| {
                    var vreg_iter = succ_live_in.keyIterator();
                    while (vreg_iter.next()) |vreg_id| {
                        try new_live_out.put(vreg_id.*, {});
                    }
                }
            }

            // Add live_in from all exception successors (exception edges)
            var exc_succ_iter = block.exception_successors.keyIterator();
            while (exc_succ_iter.next()) |exc_succ_block| {
                const exc_succ_id = exc_succ_block.toIndex();
                if (block_live_in.get(@intCast(exc_succ_id))) |exc_succ_live_in| {
                    var vreg_iter = exc_succ_live_in.keyIterator();
                    while (vreg_iter.next()) |vreg_id| {
                        try new_live_out.put(vreg_id.*, {});
                    }
                }
            }

            // Check if live_out changed
            var old_live_out = block_live_out.getPtr(block_id) orelse continue;
            if (old_live_out.count() != new_live_out.count()) {
                changed = true;
            } else {
                var iter = new_live_out.keyIterator();
                while (iter.next()) |vreg_id| {
                    if (!old_live_out.contains(vreg_id.*)) {
                        changed = true;
                        break;
                    }
                }
            }

            // Update live_out
            old_live_out.clearRetainingCapacity();
            var iter = new_live_out.keyIterator();
            while (iter.next()) |vreg_id| {
                try old_live_out.put(vreg_id.*, {});
            }

            // Compute live_in[B] = uses[B] ∪ (live_out[B] - defs[B])
            const insns = block_insns.get(block_id) orelse continue;

            var new_live_in = std.AutoHashMap(u32, void).init(allocator);
            defer new_live_in.deinit();

            // Start with live_out
            var live_out = old_live_out;
            var lo_iter = live_out.keyIterator();
            while (lo_iter.next()) |vreg_id| {
                try new_live_in.put(vreg_id.*, {});
            }

            // Process instructions in reverse order
            var inst_idx: i32 = @intCast(insns.len - 1);
            while (inst_idx >= 0) : (inst_idx -= 1) {
                const inst = insns[@intCast(inst_idx)];

                // Remove defs from live_in
                const defs = try inst.getDefs(allocator);
                defer allocator.free(defs);
                for (defs) |def| {
                    _ = new_live_in.remove(def.index());
                }

                // Add uses to live_in
                const uses = try inst.getUses(allocator);
                defer allocator.free(uses);
                for (uses) |use| {
                    try new_live_in.put(use.index(), {});
                }
            }

            // Check if live_in changed
            var old_live_in = block_live_in.getPtr(block_id) orelse continue;
            if (old_live_in.count() != new_live_in.count()) {
                changed = true;
            } else {
                var in_iter = new_live_in.keyIterator();
                while (in_iter.next()) |vreg_id| {
                    if (!old_live_in.contains(vreg_id.*)) {
                        changed = true;
                        break;
                    }
                }
            }

            // Update live_in
            old_live_in.clearRetainingCapacity();
            var in_iter = new_live_in.keyIterator();
            while (in_iter.next()) |vreg_id| {
                try old_live_in.put(vreg_id.*, {});
            }
        }
    }

    // Convert liveness info to live ranges
    var vreg_ranges = std.AutoHashMap(u32, struct { start: u32, end: u32, class: machinst.RegClass }).init(allocator);
    defer vreg_ranges.deinit();

    var block_starts = try allocator.alloc(u32, blocks.len);
    defer allocator.free(block_starts);

    var inst_cursor: u32 = 0;
    for (0..blocks.len) |block_idx| {
        block_starts[block_idx] = inst_cursor;
        if (block_insns.get(@intCast(block_idx))) |insns| {
            inst_cursor += @intCast(insns.len);
        }
    }

    for (0..blocks.len) |block_idx| {
        const block_id: u32 = @intCast(block_idx);
        const insns = block_insns.get(block_id) orelse continue;
        if (insns.len == 0) continue;

        const start_inst = block_starts[block_idx];

        for (insns, 0..) |inst, local_idx| {
            const inst_idx: u32 = start_inst + @as(u32, @intCast(local_idx));

            const uses = try inst.getUses(allocator);
            defer allocator.free(uses);
            for (uses) |use| {
                const entry = try vreg_ranges.getOrPut(use.index());
                if (!entry.found_existing) {
                    entry.value_ptr.* = .{
                        .start = inst_idx,
                        .end = inst_idx,
                        .class = use.class(),
                    };
                } else {
                    entry.value_ptr.start = @min(entry.value_ptr.start, inst_idx);
                    entry.value_ptr.end = @max(entry.value_ptr.end, inst_idx);
                }
            }

            const defs = try inst.getDefs(allocator);
            defer allocator.free(defs);
            for (defs) |def| {
                const entry = try vreg_ranges.getOrPut(def.index());
                if (!entry.found_existing) {
                    entry.value_ptr.* = .{
                        .start = inst_idx,
                        .end = inst_idx,
                        .class = def.class(),
                    };
                } else {
                    entry.value_ptr.start = @min(entry.value_ptr.start, inst_idx);
                    entry.value_ptr.end = @max(entry.value_ptr.end, inst_idx);
                }
            }
        }
    }

    for (0..blocks.len) |block_idx| {
        const block_id: u32 = @intCast(block_idx);
        const insns = block_insns.get(block_id) orelse continue;
        if (insns.len == 0) continue;

        const start_inst = block_starts[block_idx];
        const end_inst = start_inst + @as(u32, @intCast(insns.len)) - 1;

        if (block_live_in.get(block_id)) |live_in| {
            var vreg_iter = live_in.keyIterator();
            while (vreg_iter.next()) |vreg_id| {
                const entry = vreg_ranges.getPtr(vreg_id.*) orelse continue;
                entry.start = @min(entry.start, start_inst);
                entry.end = @max(entry.end, end_inst);
            }
        }

        if (block_live_out.get(block_id)) |live_out| {
            var vreg_iter = live_out.keyIterator();
            while (vreg_iter.next()) |vreg_id| {
                const entry = vreg_ranges.getPtr(vreg_id.*) orelse continue;
                entry.start = @min(entry.start, start_inst);
                entry.end = @max(entry.end, end_inst);
            }
        }
    }

    // Convert to LiveRange objects
    var iter = vreg_ranges.iterator();
    while (iter.next()) |entry| {
        const vreg_id = entry.key_ptr.*;
        const range_info = entry.value_ptr.*;
        try info.addRange(.{
            .vreg = machinst.VReg.new(vreg_id, range_info.class),
            .start_inst = range_info.start,
            .end_inst = range_info.end,
            .reg_class = range_info.class,
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

// Mock instruction type for testing computeLiveness
const MockInst = struct {
    defs: []const machinst.VReg,
    uses: []const machinst.VReg,

    pub fn getDefs(self: MockInst, allocator: std.mem.Allocator) ![]machinst.VReg {
        return try allocator.dupe(machinst.VReg, self.defs);
    }

    pub fn getUses(self: MockInst, allocator: std.mem.Allocator) ![]machinst.VReg {
        return try allocator.dupe(machinst.VReg, self.uses);
    }
};

test "computeLiveness simple def-use pattern" {
    const allocator = std.testing.allocator;

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .int);

    // Instruction 0: v0 = ...
    // Instruction 1: v1 = ... v0
    // Instruction 2: ... v1
    const insns = [_]MockInst{
        .{ .defs = &[_]machinst.VReg{v0}, .uses = &[_]machinst.VReg{} },
        .{ .defs = &[_]machinst.VReg{v1}, .uses = &[_]machinst.VReg{v0} },
        .{ .defs = &[_]machinst.VReg{}, .uses = &[_]machinst.VReg{v1} },
    };

    var info = try computeLiveness(MockInst, &insns, allocator);
    defer info.deinit();

    // v0 should be live from 0 to 1
    const r0 = info.getRange(v0);
    try std.testing.expect(r0 != null);
    try std.testing.expectEqual(@as(u32, 0), r0.?.start_inst);
    try std.testing.expectEqual(@as(u32, 1), r0.?.end_inst);

    // v1 should be live from 1 to 2
    const r1 = info.getRange(v1);
    try std.testing.expect(r1 != null);
    try std.testing.expectEqual(@as(u32, 1), r1.?.start_inst);
    try std.testing.expectEqual(@as(u32, 2), r1.?.end_inst);

    // v0 and v1 should overlap at instruction 1
    try std.testing.expect(r0.?.overlaps(r1.?.*));
}

test "computeLiveness non-overlapping ranges" {
    const allocator = std.testing.allocator;

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .int);

    // Instruction 0: v0 = ...
    // Instruction 1: ... v0
    // Instruction 2: v1 = ...
    // Instruction 3: ... v1
    const insns = [_]MockInst{
        .{ .defs = &[_]machinst.VReg{v0}, .uses = &[_]machinst.VReg{} },
        .{ .defs = &[_]machinst.VReg{}, .uses = &[_]machinst.VReg{v0} },
        .{ .defs = &[_]machinst.VReg{v1}, .uses = &[_]machinst.VReg{} },
        .{ .defs = &[_]machinst.VReg{}, .uses = &[_]machinst.VReg{v1} },
    };

    var info = try computeLiveness(MockInst, &insns, allocator);
    defer info.deinit();

    // v0 should be live from 0 to 1
    const r0 = info.getRange(v0);
    try std.testing.expect(r0 != null);
    try std.testing.expectEqual(@as(u32, 0), r0.?.start_inst);
    try std.testing.expectEqual(@as(u32, 1), r0.?.end_inst);

    // v1 should be live from 2 to 3
    const r1 = info.getRange(v1);
    try std.testing.expect(r1 != null);
    try std.testing.expectEqual(@as(u32, 2), r1.?.start_inst);
    try std.testing.expectEqual(@as(u32, 3), r1.?.end_inst);

    // v0 and v1 should NOT overlap
    try std.testing.expect(!r0.?.overlaps(r1.?.*));
    try std.testing.expect(!info.interfere(v0, v1));
}

test "computeLiveness multiple uses extend range" {
    const allocator = std.testing.allocator;

    const v0 = machinst.VReg.new(0, .int);

    // Instruction 0: v0 = ...
    // Instruction 1: ... v0
    // Instruction 2: nop
    // Instruction 3: ... v0
    const insns = [_]MockInst{
        .{ .defs = &[_]machinst.VReg{v0}, .uses = &[_]machinst.VReg{} },
        .{ .defs = &[_]machinst.VReg{}, .uses = &[_]machinst.VReg{v0} },
        .{ .defs = &[_]machinst.VReg{}, .uses = &[_]machinst.VReg{} },
        .{ .defs = &[_]machinst.VReg{}, .uses = &[_]machinst.VReg{v0} },
    };

    var info = try computeLiveness(MockInst, &insns, allocator);
    defer info.deinit();

    // v0 should be live from 0 to 3 (extended by later use)
    const r0 = info.getRange(v0);
    try std.testing.expect(r0 != null);
    try std.testing.expectEqual(@as(u32, 0), r0.?.start_inst);
    try std.testing.expectEqual(@as(u32, 3), r0.?.end_inst);
}

test "computeLiveness use before def (parameters)" {
    const allocator = std.testing.allocator;

    const v0 = machinst.VReg.new(0, .int);

    // Instruction 0: ... v0  (use before def - parameter)
    // Instruction 1: v0 = ... (definition comes later)
    const insns = [_]MockInst{
        .{ .defs = &[_]machinst.VReg{}, .uses = &[_]machinst.VReg{v0} },
        .{ .defs = &[_]machinst.VReg{v0}, .uses = &[_]machinst.VReg{} },
    };

    var info = try computeLiveness(MockInst, &insns, allocator);
    defer info.deinit();

    // v0 should be live from 0 (first use) to 1 (last use = def)
    const r0 = info.getRange(v0);
    try std.testing.expect(r0 != null);
    try std.testing.expectEqual(@as(u32, 0), r0.?.start_inst);
    try std.testing.expectEqual(@as(u32, 1), r0.?.end_inst);
}

test "computeLiveness different register classes" {
    const allocator = std.testing.allocator;

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .float);
    const v2 = machinst.VReg.new(2, .vector);

    // All defined and used at same time
    const insns = [_]MockInst{
        .{ .defs = &[_]machinst.VReg{ v0, v1, v2 }, .uses = &[_]machinst.VReg{} },
        .{ .defs = &[_]machinst.VReg{}, .uses = &[_]machinst.VReg{ v0, v1, v2 } },
    };

    var info = try computeLiveness(MockInst, &insns, allocator);
    defer info.deinit();

    // Check all have correct register classes
    const r0 = info.getRange(v0);
    const r1 = info.getRange(v1);
    const r2 = info.getRange(v2);

    try std.testing.expect(r0 != null);
    try std.testing.expect(r1 != null);
    try std.testing.expect(r2 != null);

    try std.testing.expectEqual(machinst.RegClass.int, r0.?.reg_class);
    try std.testing.expectEqual(machinst.RegClass.float, r1.?.reg_class);
    try std.testing.expectEqual(machinst.RegClass.vector, r2.?.reg_class);
}
