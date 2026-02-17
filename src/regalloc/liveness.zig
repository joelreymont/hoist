//! Liveness analysis for register allocation.
//!
//! This module provides data structures and algorithms for computing live ranges
//! of virtual registers, which is essential for register allocation.

const std = @import("std");
const machinst = @import("../machinst/machinst.zig");
const cfg_mod = @import("../ir/cfg.zig");

const max_operand_regs: usize = 128;

const StackOperandCollector = struct {
    uses_buf: [max_operand_regs]machinst.Reg = undefined,
    defs_buf: [max_operand_regs]machinst.WritableReg = undefined,
    uses_len: usize = 0,
    defs_len: usize = 0,

    fn reset(self: *StackOperandCollector) void {
        self.uses_len = 0;
        self.defs_len = 0;
    }

    pub fn regUse(self: *StackOperandCollector, reg: machinst.Reg) !void {
        if (self.uses_len >= max_operand_regs) return error.OutOfMemory;
        self.uses_buf[self.uses_len] = reg;
        self.uses_len += 1;
    }

    pub fn regDef(self: *StackOperandCollector, reg: machinst.WritableReg) !void {
        if (self.defs_len >= max_operand_regs) return error.OutOfMemory;
        self.defs_buf[self.defs_len] = reg;
        self.defs_len += 1;
    }

    pub fn regLateDef(self: *StackOperandCollector, reg: machinst.WritableReg) !void {
        return self.regDef(reg);
    }

    fn uses(self: *const StackOperandCollector) []const machinst.Reg {
        return self.uses_buf[0..self.uses_len];
    }

    fn defs(self: *const StackOperandCollector) []const machinst.WritableReg {
        return self.defs_buf[0..self.defs_len];
    }
};

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

    /// Instruction indices of call/call_indirect instructions.
    /// Live ranges that span any of these positions must be allocated
    /// to callee-saved registers (or spilled).
    call_positions: std.ArrayList(u32),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LivenessInfo {
        return .{
            .ranges = std.ArrayList(LiveRange){},
            .vreg_to_range = std.AutoHashMap(u32, u32).init(allocator),
            .call_positions = std.ArrayList(u32){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LivenessInfo) void {
        self.ranges.deinit(self.allocator);
        self.vreg_to_range.deinit();
        self.call_positions.deinit(self.allocator);
    }

    /// Check if a live range spans any call instruction.
    /// A range "spans" a call if the call occurs strictly inside [start, end),
    /// meaning the value is defined before the call and used after it.
    /// Values whose last use IS the call (arguments) don't need to survive it.
    pub fn spansCall(self: *const LivenessInfo, range: LiveRange) bool {
        for (self.call_positions.items) |call_pos| {
            if (call_pos > range.start_inst and call_pos < range.end_inst) {
                return true;
            }
        }
        return false;
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

    /// Compute liveness from VCode.
    /// The VCode type must have an `insns` field containing instruction slice.
    pub fn compute(
        comptime Inst: type,
        allocator: std.mem.Allocator,
        vcode: anytype,
    ) !LivenessInfo {
        return computeLiveness(Inst, vcode.insns.items, allocator);
    }
};

/// Helper to track per-vreg information during liveness computation
const VRegInfo = struct {
    first_def: ?u32,
    first_use: ?u32,
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
    const has_get_operands = comptime @hasDecl(Inst, "getOperands");
    var operand_collector = StackOperandCollector{};

    // Forward scan through instructions
    for (insns, 0..) |inst, idx| {
        const inst_idx: u32 = @intCast(idx);

        // Track call positions for caller-saved register handling
        if (inst.isCall()) {
            try info.call_positions.append(allocator, inst_idx);
        }

        if (comptime has_get_operands) {
            operand_collector.reset();
            try inst.getOperands(&operand_collector);

            // Process definitions - mark start of live range
            for (operand_collector.defs()) |def| {
                const vreg = def.toReg().toVReg() orelse continue;
                const entry = try vreg_info.getOrPut(vreg.index());
                if (!entry.found_existing) {
                    entry.value_ptr.* = .{
                        .first_def = inst_idx,
                        .first_use = null,
                        .last_use = inst_idx,
                        .reg_class = vreg.class(),
                    };
                } else {
                    // Multiple definitions - this is unusual but possible with phi nodes
                    // Keep the first definition
                    if (entry.value_ptr.first_def == null) {
                        entry.value_ptr.first_def = inst_idx;
                        if (entry.value_ptr.last_use < inst_idx) {
                            entry.value_ptr.last_use = inst_idx;
                        }
                    }
                }
            }

            // Process uses - extend live range
            for (operand_collector.uses()) |use| {
                const vreg = use.toVReg() orelse continue;
                const entry = try vreg_info.getOrPut(vreg.index());
                if (!entry.found_existing) {
                    // Use before def - this can happen with function parameters
                    // Treat the use as both the start and current end
                    entry.value_ptr.* = .{
                        .first_def = null, // No definition yet
                        .first_use = inst_idx,
                        .last_use = inst_idx,
                        .reg_class = vreg.class(),
                    };
                } else {
                    if (entry.value_ptr.first_use == null) {
                        entry.value_ptr.first_use = inst_idx;
                    }
                    // Update last use
                    entry.value_ptr.last_use = inst_idx;
                }
            }
        } else {
            // Process definitions - mark start of live range
            const defs = try inst.getDefs(allocator);
            defer allocator.free(defs);

            for (defs) |vreg| {
                const entry = try vreg_info.getOrPut(vreg.index());
                if (!entry.found_existing) {
                    entry.value_ptr.* = .{
                        .first_def = inst_idx,
                        .first_use = null,
                        .last_use = inst_idx,
                        .reg_class = vreg.class(),
                    };
                } else {
                    // Multiple definitions - this is unusual but possible with phi nodes
                    // Keep the first definition
                    if (entry.value_ptr.first_def == null) {
                        entry.value_ptr.first_def = inst_idx;
                        if (entry.value_ptr.last_use < inst_idx) {
                            entry.value_ptr.last_use = inst_idx;
                        }
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
                        .first_use = inst_idx,
                        .last_use = inst_idx,
                        .reg_class = vreg.class(),
                    };
                } else {
                    if (entry.value_ptr.first_use == null) {
                        entry.value_ptr.first_use = inst_idx;
                    }
                    // Update last use
                    entry.value_ptr.last_use = inst_idx;
                }
            }
        }
    }

    // Convert vreg_info to live ranges
    var iter = vreg_info.iterator();
    while (iter.next()) |entry| {
        const vreg_idx = entry.key_ptr.*;
        const vinfo = entry.value_ptr.*;

        // Start is either first definition or first use (for parameters)
        const start = if (vinfo.first_def) |def|
            if (vinfo.first_use) |use| @min(def, use) else def
        else
            vinfo.first_use orelse 0;

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
    block_insns: []const ?[]const Inst,
    allocator: std.mem.Allocator,
) !LivenessInfo {
    std.debug.assert(blocks.len == block_insns.len);

    var info = LivenessInfo.init(allocator);
    errdefer info.deinit();

    var block_live_in = try allocator.alloc(std.AutoHashMap(u32, void), blocks.len);
    defer {
        for (block_live_in) |*set| {
            set.deinit();
        }
        allocator.free(block_live_in);
    }

    var block_live_out = try allocator.alloc(std.AutoHashMap(u32, void), blocks.len);
    defer {
        for (block_live_out) |*set| {
            set.deinit();
        }
        allocator.free(block_live_out);
    }

    const has_get_operands = comptime @hasDecl(Inst, "getOperands");
    var operand_collector = StackOperandCollector{};

    for (0..blocks.len) |block_idx| {
        block_live_in[block_idx] = std.AutoHashMap(u32, void).init(allocator);
        block_live_out[block_idx] = std.AutoHashMap(u32, void).init(allocator);
    }

    var new_live_out = std.AutoHashMap(u32, void).init(allocator);
    defer new_live_out.deinit();

    var new_live_in = std.AutoHashMap(u32, void).init(allocator);
    defer new_live_in.deinit();

    const Set = std.AutoHashMap(u32, void);

    const setChanged = struct {
        fn check(old_set: *const Set, new_set: *const Set) bool {
            if (old_set.count() != new_set.count()) return true;
            var it = new_set.keyIterator();
            while (it.next()) |vreg_id| {
                if (!old_set.contains(vreg_id.*)) return true;
            }
            return false;
        }
    }.check;

    var changed = true;
    while (changed) {
        changed = false;

        var block_idx: i32 = @intCast(blocks.len - 1);
        while (block_idx >= 0) : (block_idx -= 1) {
            const idx: usize = @intCast(block_idx);
            const block = &blocks[idx];

            new_live_out.clearRetainingCapacity();

            var succ_iter = block.successors.keyIterator();
            while (succ_iter.next()) |succ_block| {
                const succ_id = succ_block.toIndex();
                const succ_live_in = &block_live_in[succ_id];
                var vreg_iter = succ_live_in.keyIterator();
                while (vreg_iter.next()) |vreg_id| {
                    try new_live_out.put(vreg_id.*, {});
                }
            }

            var exc_succ_iter = block.exception_successors.keyIterator();
            while (exc_succ_iter.next()) |exc_succ_block| {
                const exc_succ_id = exc_succ_block.toIndex();
                const exc_succ_live_in = &block_live_in[exc_succ_id];
                var vreg_iter = exc_succ_live_in.keyIterator();
                while (vreg_iter.next()) |vreg_id| {
                    try new_live_out.put(vreg_id.*, {});
                }
            }

            const old_live_out = &block_live_out[idx];
            changed = changed or setChanged(old_live_out, &new_live_out);
            old_live_out.clearRetainingCapacity();
            var out_iter = new_live_out.keyIterator();
            while (out_iter.next()) |vreg_id| {
                try old_live_out.put(vreg_id.*, {});
            }

            const insns = block_insns[idx] orelse continue;

            new_live_in.clearRetainingCapacity();
            var lo_iter = old_live_out.keyIterator();
            while (lo_iter.next()) |vreg_id| {
                try new_live_in.put(vreg_id.*, {});
            }

            var inst_idx: i32 = @intCast(insns.len - 1);
            while (inst_idx >= 0) : (inst_idx -= 1) {
                const inst = insns[@intCast(inst_idx)];

                if (comptime has_get_operands) {
                    operand_collector.reset();
                    try inst.getOperands(&operand_collector);

                    for (operand_collector.defs()) |def| {
                        if (def.toReg().toVReg()) |vreg| {
                            _ = new_live_in.remove(vreg.index());
                        }
                    }

                    for (operand_collector.uses()) |use| {
                        if (use.toVReg()) |vreg| {
                            try new_live_in.put(vreg.index(), {});
                        }
                    }
                } else {
                    const defs = try inst.getDefs(allocator);
                    defer allocator.free(defs);
                    for (defs) |def| {
                        _ = new_live_in.remove(def.index());
                    }

                    const uses = try inst.getUses(allocator);
                    defer allocator.free(uses);
                    for (uses) |use| {
                        try new_live_in.put(use.index(), {});
                    }
                }
            }

            const old_live_in = &block_live_in[idx];
            changed = changed or setChanged(old_live_in, &new_live_in);
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
        if (block_insns[block_idx]) |insns| {
            inst_cursor += @intCast(insns.len);
        }
    }

    for (0..blocks.len) |block_idx| {
        const insns = block_insns[block_idx] orelse continue;
        if (insns.len == 0) continue;

        const start_inst = block_starts[block_idx];

        for (insns, 0..) |inst, local_idx| {
            const inst_idx: u32 = start_inst + @as(u32, @intCast(local_idx));

            // Track call positions for caller-saved register handling
            if (inst.isCall()) {
                try info.call_positions.append(allocator, inst_idx);
            }

            if (comptime has_get_operands) {
                operand_collector.reset();
                try inst.getOperands(&operand_collector);

                for (operand_collector.uses()) |use| {
                    const vreg = use.toVReg() orelse continue;
                    const entry = try vreg_ranges.getOrPut(vreg.index());
                    if (!entry.found_existing) {
                        entry.value_ptr.* = .{
                            .start = inst_idx,
                            .end = inst_idx,
                            .class = vreg.class(),
                        };
                    } else {
                        entry.value_ptr.start = @min(entry.value_ptr.start, inst_idx);
                        entry.value_ptr.end = @max(entry.value_ptr.end, inst_idx);
                    }
                }

                for (operand_collector.defs()) |def| {
                    const vreg = def.toReg().toVReg() orelse continue;
                    const entry = try vreg_ranges.getOrPut(vreg.index());
                    if (!entry.found_existing) {
                        entry.value_ptr.* = .{
                            .start = inst_idx,
                            .end = inst_idx,
                            .class = vreg.class(),
                        };
                    } else {
                        entry.value_ptr.start = @min(entry.value_ptr.start, inst_idx);
                        entry.value_ptr.end = @max(entry.value_ptr.end, inst_idx);
                    }
                }
            } else {
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
    }

    for (0..blocks.len) |block_idx| {
        const insns = block_insns[block_idx] orelse continue;
        if (insns.len == 0) continue;

        const start_inst = block_starts[block_idx];
        const end_inst = start_inst + @as(u32, @intCast(insns.len)) - 1;

        const live_in = &block_live_in[block_idx];
        var in_iter = live_in.keyIterator();
        while (in_iter.next()) |vreg_id| {
            const entry = vreg_ranges.getPtr(vreg_id.*) orelse continue;
            entry.start = @min(entry.start, start_inst);
            entry.end = @max(entry.end, end_inst);
        }

        const live_out = &block_live_out[block_idx];
        var out_iter = live_out.keyIterator();
        while (out_iter.next()) |vreg_id| {
            const entry = vreg_ranges.getPtr(vreg_id.*) orelse continue;
            entry.start = @min(entry.start, start_inst);
            entry.end = @max(entry.end, end_inst);
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
    is_call: bool = false,

    pub fn getDefs(self: MockInst, allocator: std.mem.Allocator) ![]machinst.VReg {
        return try allocator.dupe(machinst.VReg, self.defs);
    }

    pub fn getUses(self: MockInst, allocator: std.mem.Allocator) ![]machinst.VReg {
        return try allocator.dupe(machinst.VReg, self.uses);
    }

    pub fn isCall(self: *const MockInst) bool {
        return self.is_call;
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

test "computeLivenessWithCFG indexed block slices" {
    const allocator = std.testing.allocator;
    const Block = @import("../ir/entities.zig").Block;

    const v0 = machinst.VReg.new(7, .int);

    var nodes = try allocator.alloc(cfg_mod.CFGNode, 2);
    defer allocator.free(nodes);
    nodes[0] = cfg_mod.CFGNode.init(allocator);
    nodes[1] = cfg_mod.CFGNode.init(allocator);
    defer {
        nodes[0].predecessors.deinit();
        nodes[0].successors.deinit();
        nodes[0].exception_successors.deinit();
        nodes[1].predecessors.deinit();
        nodes[1].successors.deinit();
        nodes[1].exception_successors.deinit();
    }

    try nodes[0].successors.put(Block.new(1), {});

    const block0 = [_]MockInst{
        .{ .defs = &[_]machinst.VReg{v0}, .uses = &[_]machinst.VReg{} },
    };
    const block1 = [_]MockInst{
        .{ .defs = &[_]machinst.VReg{}, .uses = &[_]machinst.VReg{v0} },
    };
    const block_insns = [_]?[]const MockInst{
        block0[0..],
        block1[0..],
    };

    var info = try computeLivenessWithCFG(MockInst, nodes, &block_insns, allocator);
    defer info.deinit();

    const range = info.getRange(v0);
    try std.testing.expect(range != null);
    try std.testing.expectEqual(@as(u32, 0), range.?.start_inst);
    try std.testing.expectEqual(@as(u32, 1), range.?.end_inst);
}
