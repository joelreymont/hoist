//! Liveness analysis for register allocation.
//!
//! This module provides data structures and algorithms for computing live ranges
//! of virtual registers, which is essential for register allocation.

const std = @import("std");
const machinst = @import("../machinst/machinst.zig");
const cfg_mod = @import("../ir/cfg.zig");

const max_operand_regs: usize = 128;
const invalid_range_idx: u32 = std.math.maxInt(u32);

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

    /// Dense map from vreg index to live-range index in `ranges`.
    /// Unused entries are `invalid_range_idx`.
    vreg_to_range_dense: std.ArrayList(u32),

    /// Instruction indices of call/call_indirect instructions.
    /// Live ranges that span any of these positions must be allocated
    /// to callee-saved registers (or spilled).
    call_positions: std.ArrayList(u32),

    /// True if `ranges` are sorted by `start_inst` ascending.
    ranges_sorted_by_start: bool,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LivenessInfo {
        return .{
            .ranges = std.ArrayList(LiveRange){},
            .vreg_to_range_dense = std.ArrayList(u32){},
            .call_positions = std.ArrayList(u32){},
            .ranges_sorted_by_start = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LivenessInfo) void {
        self.ranges.deinit(self.allocator);
        self.vreg_to_range_dense.deinit(self.allocator);
        self.call_positions.deinit(self.allocator);
    }

    pub fn clearRetainingCapacity(self: *LivenessInfo) void {
        self.ranges.clearRetainingCapacity();
        @memset(self.vreg_to_range_dense.items, invalid_range_idx);
        self.call_positions.clearRetainingCapacity();
        self.ranges_sorted_by_start = false;
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
        try self.setRangeIndex(range.vreg.index(), range_idx);
        self.ranges_sorted_by_start = false;
    }

    /// Get the live range for a given virtual register
    /// Returns null if the vreg has no recorded live range
    pub fn getRange(self: *LivenessInfo, vreg: machinst.VReg) ?*const LiveRange {
        const vreg_idx = vreg.index();
        if (vreg_idx >= self.vreg_to_range_dense.items.len) return null;
        const range_idx = self.vreg_to_range_dense.items[vreg_idx];
        if (range_idx == invalid_range_idx) return null;
        return &self.ranges.items[range_idx];
    }

    fn setRangeIndex(self: *LivenessInfo, vreg_idx: u32, range_idx: u32) !void {
        try self.ensureDenseCapacity(vreg_idx);
        self.vreg_to_range_dense.items[vreg_idx] = range_idx;
    }

    fn ensureDenseCapacity(self: *LivenessInfo, vreg_idx: u32) !void {
        if (vreg_idx < self.vreg_to_range_dense.items.len) return;
        const old_len = self.vreg_to_range_dense.items.len;
        const new_len: usize = @as(usize, vreg_idx) + 1;
        try self.vreg_to_range_dense.resize(self.allocator, new_len);
        @memset(self.vreg_to_range_dense.items[old_len..new_len], invalid_range_idx);
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
    try computeLivenessInto(Inst, insns, &info);
    return info;
}

pub fn computeLivenessInto(
    comptime Inst: type,
    insns: []const Inst,
    info: *LivenessInfo,
) !void {
    info.clearRetainingCapacity();
    const allocator = info.allocator;

    if (insns.len > 0) {
        // Single-block fast path sees monotonic vreg growth on synthetic and real workloads.
        // Pre-sizing avoids repeated range growth while building ranges.
        try info.ranges.ensureTotalCapacity(allocator, insns.len);
    }

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

            for (operand_collector.defs()) |def| {
                const vreg = def.toReg().toVReg() orelse continue;
                try noteRangeUse(info, vreg, inst_idx);
            }

            for (operand_collector.uses()) |use| {
                const vreg = use.toVReg() orelse continue;
                try noteRangeUse(info, vreg, inst_idx);
            }
        } else {
            const defs = try inst.getDefs(allocator);
            defer allocator.free(defs);
            for (defs) |vreg| {
                try noteRangeUse(info, vreg, inst_idx);
            }

            const uses = try inst.getUses(allocator);
            defer allocator.free(uses);
            for (uses) |vreg| {
                try noteRangeUse(info, vreg, inst_idx);
            }
        }
    }
    info.ranges_sorted_by_start = true;
}

fn noteRangeUse(info: *LivenessInfo, vreg: machinst.VReg, inst_idx: u32) !void {
    const vreg_idx = vreg.index();
    try info.ensureDenseCapacity(vreg_idx);
    const range_idx = info.vreg_to_range_dense.items[vreg_idx];
    if (range_idx != invalid_range_idx) {
        const range = &info.ranges.items[range_idx];
        range.start_inst = @min(range.start_inst, inst_idx);
        range.end_inst = @max(range.end_inst, inst_idx);
        return;
    }

    const new_idx: u32 = @intCast(info.ranges.items.len);
    try info.ranges.append(info.allocator, .{
        .vreg = vreg,
        .start_inst = inst_idx,
        .end_inst = inst_idx,
        .reg_class = vreg.class(),
    });
    info.vreg_to_range_dense.items[vreg_idx] = new_idx;
}

fn allocBitSetArray(
    allocator: std.mem.Allocator,
    len: usize,
    bit_length: usize,
) ![]std.DynamicBitSetUnmanaged {
    const sets = try allocator.alloc(std.DynamicBitSetUnmanaged, len);
    errdefer allocator.free(sets);

    var init_len: usize = 0;
    errdefer {
        for (sets[0..init_len]) |*set| {
            set.deinit(allocator);
        }
    }

    for (sets) |*set| {
        set.* = try std.DynamicBitSetUnmanaged.initEmpty(allocator, bit_length);
        init_len += 1;
    }
    return sets;
}

fn freeBitSetArray(allocator: std.mem.Allocator, sets: []std.DynamicBitSetUnmanaged) void {
    for (sets) |*set| {
        set.deinit(allocator);
    }
    allocator.free(sets);
}

fn bitSetMaskCount(bit_length: usize) usize {
    return (bit_length + (@bitSizeOf(usize) - 1)) / @bitSizeOf(usize);
}

fn subtractBitSet(
    dst: *std.DynamicBitSetUnmanaged,
    rhs: *const std.DynamicBitSetUnmanaged,
    masks_len: usize,
) void {
    for (0..masks_len) |i| {
        dst.masks[i] &= ~rhs.masks[i];
    }
}

fn copyBitSetIfChanged(
    dst: *std.DynamicBitSetUnmanaged,
    src: *const std.DynamicBitSetUnmanaged,
    masks_len: usize,
) bool {
    if (dst.eql(src.*)) return false;
    @memcpy(dst.masks[0..masks_len], src.masks[0..masks_len]);
    return true;
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
    var info = LivenessInfo.init(allocator);
    errdefer info.deinit();
    try computeLivenessWithCFGInto(Inst, blocks, block_insns, &info);
    return info;
}

pub fn computeLivenessWithCFGInto(
    comptime Inst: type,
    blocks: []const cfg_mod.CFGNode,
    block_insns: []const ?[]const Inst,
    info: *LivenessInfo,
) !void {
    std.debug.assert(blocks.len == block_insns.len);
    info.clearRetainingCapacity();
    const allocator = info.allocator;

    const has_get_operands = comptime @hasDecl(Inst, "getOperands");
    var operand_collector = StackOperandCollector{};

    var vreg_count: usize = 0;
    for (block_insns) |insns_opt| {
        const insns = insns_opt orelse continue;
        for (insns) |inst| {
            if (comptime has_get_operands) {
                operand_collector.reset();
                try inst.getOperands(&operand_collector);

                for (operand_collector.uses()) |use| {
                    const vreg = use.toVReg() orelse continue;
                    vreg_count = @max(vreg_count, @as(usize, vreg.index()) + 1);
                }
                for (operand_collector.defs()) |def| {
                    const vreg = def.toReg().toVReg() orelse continue;
                    vreg_count = @max(vreg_count, @as(usize, vreg.index()) + 1);
                }
            } else {
                const uses = try inst.getUses(allocator);
                defer allocator.free(uses);
                for (uses) |use| {
                    vreg_count = @max(vreg_count, @as(usize, use.index()) + 1);
                }

                const defs = try inst.getDefs(allocator);
                defer allocator.free(defs);
                for (defs) |def| {
                    vreg_count = @max(vreg_count, @as(usize, def.index()) + 1);
                }
            }
        }
    }

    const masks_len = bitSetMaskCount(vreg_count);

    var block_live_in = try allocBitSetArray(allocator, blocks.len, vreg_count);
    defer freeBitSetArray(allocator, block_live_in);

    var block_live_out = try allocBitSetArray(allocator, blocks.len, vreg_count);
    defer freeBitSetArray(allocator, block_live_out);

    var block_uses = try allocBitSetArray(allocator, blocks.len, vreg_count);
    defer freeBitSetArray(allocator, block_uses);

    var block_defs = try allocBitSetArray(allocator, blocks.len, vreg_count);
    defer freeBitSetArray(allocator, block_defs);

    for (0..blocks.len) |block_idx| {
        const insns = block_insns[block_idx] orelse continue;
        for (insns) |inst| {
            if (comptime has_get_operands) {
                operand_collector.reset();
                try inst.getOperands(&operand_collector);

                for (operand_collector.uses()) |use| {
                    const vreg = use.toVReg() orelse continue;
                    const vreg_idx: usize = @intCast(vreg.index());
                    if (!block_defs[block_idx].isSet(vreg_idx)) {
                        block_uses[block_idx].set(vreg_idx);
                    }
                }
                for (operand_collector.defs()) |def| {
                    const vreg = def.toReg().toVReg() orelse continue;
                    block_defs[block_idx].set(@intCast(vreg.index()));
                }
            } else {
                const uses = try inst.getUses(allocator);
                defer allocator.free(uses);
                for (uses) |use| {
                    const vreg_idx: usize = @intCast(use.index());
                    if (!block_defs[block_idx].isSet(vreg_idx)) {
                        block_uses[block_idx].set(vreg_idx);
                    }
                }

                const defs = try inst.getDefs(allocator);
                defer allocator.free(defs);
                for (defs) |def| {
                    block_defs[block_idx].set(@intCast(def.index()));
                }
            }
        }
    }

    var block_preds = try allocator.alloc(std.ArrayListUnmanaged(u32), blocks.len);
    defer {
        for (block_preds) |*preds| {
            preds.deinit(allocator);
        }
        allocator.free(block_preds);
    }
    for (block_preds) |*preds| {
        preds.* = .{};
    }

    for (blocks, 0..) |block, block_idx| {
        var succ_iter = block.successors.keyIterator();
        while (succ_iter.next()) |succ_block| {
            const succ_idx: usize = @intCast(succ_block.toIndex());
            try block_preds[succ_idx].append(allocator, @intCast(block_idx));
        }

        var exc_succ_iter = block.exception_successors.keyIterator();
        while (exc_succ_iter.next()) |succ_block| {
            const succ_idx: usize = @intCast(succ_block.toIndex());
            try block_preds[succ_idx].append(allocator, @intCast(block_idx));
        }
    }

    var worklist = std.ArrayListUnmanaged(u32){};
    defer worklist.deinit(allocator);
    try worklist.ensureTotalCapacity(allocator, blocks.len);
    var queued = try allocator.alloc(bool, blocks.len);
    defer allocator.free(queued);
    @memset(queued, true);

    var idx_rev = blocks.len;
    while (idx_rev > 0) {
        idx_rev -= 1;
        worklist.appendAssumeCapacity(@intCast(idx_rev));
    }

    var tmp_live_out = try std.DynamicBitSetUnmanaged.initEmpty(allocator, vreg_count);
    defer tmp_live_out.deinit(allocator);
    var tmp_live_in = try std.DynamicBitSetUnmanaged.initEmpty(allocator, vreg_count);
    defer tmp_live_in.deinit(allocator);

    while (worklist.pop()) |block_idx_u32| {
        const block_idx: usize = @intCast(block_idx_u32);
        queued[block_idx] = false;
        const block = &blocks[block_idx];

        tmp_live_out.unsetAll();
        var succ_iter = block.successors.keyIterator();
        while (succ_iter.next()) |succ_block| {
            const succ_idx: usize = @intCast(succ_block.toIndex());
            tmp_live_out.setUnion(block_live_in[succ_idx]);
        }
        var exc_succ_iter = block.exception_successors.keyIterator();
        while (exc_succ_iter.next()) |succ_block| {
            const succ_idx: usize = @intCast(succ_block.toIndex());
            tmp_live_out.setUnion(block_live_in[succ_idx]);
        }

        tmp_live_in.unsetAll();
        @memcpy(tmp_live_in.masks[0..masks_len], tmp_live_out.masks[0..masks_len]);
        subtractBitSet(&tmp_live_in, &block_defs[block_idx], masks_len);
        tmp_live_in.setUnion(block_uses[block_idx]);

        var changed = false;
        changed = copyBitSetIfChanged(&block_live_out[block_idx], &tmp_live_out, masks_len) or changed;
        changed = copyBitSetIfChanged(&block_live_in[block_idx], &tmp_live_in, masks_len) or changed;
        if (!changed) continue;

        for (block_preds[block_idx].items) |pred_idx_u32| {
            const pred_idx: usize = @intCast(pred_idx_u32);
            if (queued[pred_idx]) continue;
            try worklist.append(allocator, pred_idx_u32);
            queued[pred_idx] = true;
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
        var in_iter = live_in.iterator(.{});
        while (in_iter.next()) |vreg_idx| {
            const entry = vreg_ranges.getPtr(@intCast(vreg_idx)) orelse continue;
            entry.start = @min(entry.start, start_inst);
            entry.end = @max(entry.end, end_inst);
        }

        const live_out = &block_live_out[block_idx];
        var out_iter = live_out.iterator(.{});
        while (out_iter.next()) |vreg_idx| {
            const entry = vreg_ranges.getPtr(@intCast(vreg_idx)) orelse continue;
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

const PerfInst = struct {
    defs: []const machinst.VReg,
    uses: []const machinst.VReg,
    is_call: bool = false,

    pub fn getOperands(self: PerfInst, collector: anytype) !void {
        for (self.uses) |use| {
            try collector.regUse(machinst.Reg.fromVReg(use));
        }
        for (self.defs) |def| {
            try collector.regDef(machinst.WritableReg.fromVReg(def));
        }
    }

    pub fn isCall(self: *const PerfInst) bool {
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

test "computeLivenessInto matches computeLiveness" {
    const allocator = std.testing.allocator;

    const v0 = machinst.VReg.new(0, .int);
    const v1 = machinst.VReg.new(1, .int);
    const v2 = machinst.VReg.new(2, .float);

    const insns = [_]MockInst{
        .{ .defs = &[_]machinst.VReg{v0}, .uses = &[_]machinst.VReg{} },
        .{ .defs = &[_]machinst.VReg{v1}, .uses = &[_]machinst.VReg{v0} },
        .{ .defs = &[_]machinst.VReg{}, .uses = &[_]machinst.VReg{v1}, .is_call = true },
        .{ .defs = &[_]machinst.VReg{v2}, .uses = &[_]machinst.VReg{} },
        .{ .defs = &[_]machinst.VReg{}, .uses = &[_]machinst.VReg{v2} },
    };

    var owned = try computeLiveness(MockInst, &insns, allocator);
    defer owned.deinit();

    var reused = LivenessInfo.init(allocator);
    defer reused.deinit();
    try computeLivenessInto(MockInst, &insns, &reused);

    try std.testing.expectEqual(owned.ranges.items.len, reused.ranges.items.len);
    try std.testing.expectEqual(owned.call_positions.items.len, reused.call_positions.items.len);

    for ([_]machinst.VReg{ v0, v1, v2 }) |vreg| {
        const a = owned.getRange(vreg);
        const b = reused.getRange(vreg);
        try std.testing.expect(a != null);
        try std.testing.expect(b != null);
        try std.testing.expectEqual(a.?.start_inst, b.?.start_inst);
        try std.testing.expectEqual(a.?.end_inst, b.?.end_inst);
        try std.testing.expectEqual(a.?.reg_class, b.?.reg_class);
    }
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

test "computeLivenessWithCFG perf sanity on wide CFG" {
    const allocator = std.testing.allocator;
    const Block = @import("../ir/entities.zig").Block;
    const block_count: usize = 192;
    const live_width: usize = 96;
    const iterations: usize = 16;

    var nodes = try allocator.alloc(cfg_mod.CFGNode, block_count);
    defer allocator.free(nodes);
    for (0..block_count) |i| {
        nodes[i] = cfg_mod.CFGNode.init(allocator);
    }
    defer {
        for (nodes) |*node| {
            node.predecessors.deinit();
            node.successors.deinit();
            node.exception_successors.deinit();
        }
    }
    for (0..block_count - 1) |i| {
        try nodes[i].successors.put(Block.new(@intCast(i + 1)), {});
    }

    var def_storage = try allocator.alloc(machinst.VReg, block_count);
    defer allocator.free(def_storage);
    var use_storage = try allocator.alloc(machinst.VReg, block_count * live_width);
    defer allocator.free(use_storage);
    var insts = try allocator.alloc(PerfInst, block_count);
    defer allocator.free(insts);
    var block_insns = try allocator.alloc(?[]const PerfInst, block_count);
    defer allocator.free(block_insns);

    for (0..block_count) |i| {
        def_storage[i] = machinst.VReg.new(@intCast(10_000 + i), .int);
        const use_len = @min(i, live_width);
        const base = i * live_width;
        for (0..use_len) |j| {
            use_storage[base + j] = machinst.VReg.new(@intCast(10_000 + i - 1 - j), .int);
        }
        insts[i] = .{
            .defs = def_storage[i .. i + 1],
            .uses = use_storage[base .. base + use_len],
            .is_call = false,
        };
        block_insns[i] = insts[i .. i + 1];
    }

    var info = LivenessInfo.init(allocator);
    defer info.deinit();

    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        try computeLivenessWithCFGInto(PerfInst, nodes, block_insns, &info);
    }
    const avg_us = (timer.read() / iterations) / 1000;

    try std.testing.expect(info.ranges.items.len >= block_count);
    // Generous Debug-mode bound; catches accidental quadratic regressions.
    try std.testing.expect(avg_us < 200_000);
}
