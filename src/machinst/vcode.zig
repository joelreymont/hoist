const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const reg_mod = @import("reg.zig");
const machinst_mod = @import("machinst.zig");

pub const Reg = reg_mod.Reg;
pub const VReg = reg_mod.VReg;
pub const RegClass = reg_mod.RegClass;
pub const MachLabel = machinst_mod.MachLabel;

/// Index to a basic block in VCode.
pub const BlockIndex = u32;

/// Index to an instruction in VCode.
pub const InsnIndex = u32;

/// A basic block in VCode.
pub const VCodeBlock = struct {
    /// Start index of instructions in this block.
    insn_start: InsnIndex,
    /// End index (exclusive) of instructions in this block.
    insn_end: InsnIndex,
    /// Successor block indices.
    succs: []const BlockIndex,
    /// Predecessor block indices.
    preds: []const BlockIndex,
    /// Block parameters (phi nodes).
    params: []const VReg,

    pub fn insnCount(self: VCodeBlock) usize {
        return self.insn_end - self.insn_start;
    }
};

/// Virtual-register CFG - the core data structure after lowering.
///
/// VCode represents a function as a CFG of basic blocks, where each block
/// contains machine instructions that may reference virtual registers.
/// Register allocation transforms virtual registers into physical registers
/// or spill slots.
pub fn VCode(comptime Inst: type) type {
    return struct {
        /// All instructions in program order.
        insns: std.ArrayList(Inst),
        /// Basic blocks.
        blocks: std.ArrayList(VCodeBlock),
        /// Entry block index.
        entry: BlockIndex,
        /// Successor lists (concatenated for all blocks).
        succs: std.ArrayList(BlockIndex),
        /// Predecessor lists (concatenated for all blocks).
        preds: std.ArrayList(BlockIndex),
        /// Block parameter lists (concatenated for all blocks).
        block_params: std.ArrayList(VReg),
        /// Allocator.
        allocator: Allocator,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return .{
                .insns = std.ArrayList(Inst){},
                .blocks = std.ArrayList(VCodeBlock){},
                .entry = 0,
                .succs = std.ArrayList(BlockIndex){},
                .preds = std.ArrayList(BlockIndex){},
                .block_params = std.ArrayList(VReg){},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.insns.deinit(self.allocator);
            self.blocks.deinit(self.allocator);
            self.succs.deinit(self.allocator);
            self.preds.deinit(self.allocator);
            self.block_params.deinit(self.allocator);
        }

        /// Add an instruction to the current block being built.
        pub fn addInst(self: *Self, inst: Inst) !InsnIndex {
            const index: InsnIndex = @intCast(self.insns.items.len);
            try self.insns.append(self.allocator, inst);
            return index;
        }

        /// Start a new basic block.
        pub fn startBlock(
            self: *Self,
            params: []const VReg,
        ) !BlockIndex {
            const block_index: BlockIndex = @intCast(self.blocks.items.len);
            const insn_start: InsnIndex = @intCast(self.insns.items.len);

            // Copy params to concatenated array.
            const params_start = self.block_params.items.len;
            try self.block_params.appendSlice(self.allocator, params);
            const params_slice = self.block_params.items[params_start..];

            const block = VCodeBlock{
                .insn_start = insn_start,
                .insn_end = insn_start, // Will be updated when block is finished
                .succs = &.{},
                .preds = &.{},
                .params = params_slice,
            };

            try self.blocks.append(self.allocator, block);
            return block_index;
        }

        /// Finish the current block and set its successors.
        pub fn finishBlock(
            self: *Self,
            block: BlockIndex,
            successors: []const BlockIndex,
        ) !void {
            const insn_end: InsnIndex = @intCast(self.insns.items.len);

            // Copy successors to concatenated array.
            const succs_start = self.succs.items.len;
            try self.succs.appendSlice(self.allocator, successors);
            const succs_slice = self.succs.items[succs_start..];

            // Update block.
            self.blocks.items[block].insn_end = insn_end;
            self.blocks.items[block].succs = succs_slice;
        }

        /// Compute predecessor lists from successor lists.
        pub fn computePreds(self: *Self) !void {
            // Count predecessors for each block.
            var pred_counts = try self.allocator.alloc(usize, self.blocks.items.len);
            defer self.allocator.free(pred_counts);
            @memset(pred_counts, 0);

            for (self.blocks.items) |block| {
                for (block.succs) |succ| {
                    pred_counts[succ] += 1;
                }
            }

            // Allocate space in preds array.
            var pred_offsets = try self.allocator.alloc(usize, self.blocks.items.len);
            defer self.allocator.free(pred_offsets);
            var offset: usize = 0;
            for (pred_counts, 0..) |count, i| {
                pred_offsets[i] = offset;
                offset += count;
            }

            // Reserve space.
            try self.preds.resize(self.allocator, offset);
            @memset(pred_counts, 0); // Reuse as write positions

            // Fill predecessor lists.
            for (self.blocks.items, 0..) |block, block_idx| {
                for (block.succs) |succ| {
                    const pred_base = pred_offsets[succ];
                    const pred_pos = pred_base + pred_counts[succ];
                    self.preds.items[pred_pos] = @intCast(block_idx);
                    pred_counts[succ] += 1;
                }
            }

            // Update block pred slices.
            for (self.blocks.items, 0..) |*block, block_idx| {
                const start = pred_offsets[block_idx];
                const end = if (block_idx + 1 < pred_offsets.len)
                    pred_offsets[block_idx + 1]
                else
                    self.preds.items.len;
                block.preds = self.preds.items[start..end];
            }
        }

        /// Get a block by index.
        pub fn getBlock(self: *const Self, index: BlockIndex) VCodeBlock {
            return self.blocks.items[index];
        }

        /// Get an instruction by index.
        pub fn getInst(self: *const Self, index: InsnIndex) Inst {
            return self.insns.items[index];
        }

        /// Get instructions for a block.
        pub fn getBlockInsns(self: *const Self, block: BlockIndex) []const Inst {
            const b = self.blocks.items[block];
            return self.insns.items[b.insn_start..b.insn_end];
        }

        /// Get number of blocks.
        pub fn numBlocks(self: *const Self) usize {
            return self.blocks.items.len;
        }

        /// Get number of instructions.
        pub fn numInsns(self: *const Self) usize {
            return self.insns.items.len;
        }
    };
}

test "VCode basic construction" {
    const TestInst = struct { opcode: u8 };

    var vcode = VCode(TestInst).init(testing.allocator);
    defer vcode.deinit();

    // Create entry block with no parameters.
    const bb0 = try vcode.startBlock(&.{});
    try testing.expectEqual(@as(BlockIndex, 0), bb0);

    _ = try vcode.addInst(.{ .opcode = 0x90 }); // NOP
    _ = try vcode.addInst(.{ .opcode = 0xC3 }); // RET

    try vcode.finishBlock(bb0, &.{});

    try testing.expectEqual(@as(usize, 1), vcode.numBlocks());
    try testing.expectEqual(@as(usize, 2), vcode.numInsns());

    const block = vcode.getBlock(bb0);
    try testing.expectEqual(@as(usize, 2), block.insnCount());
}

test "VCode with multiple blocks" {
    const TestInst = struct { opcode: u8 };

    var vcode = VCode(TestInst).init(testing.allocator);
    defer vcode.deinit();

    // Block 0 -> Block 1, Block 2
    const bb0 = try vcode.startBlock(&.{});
    _ = try vcode.addInst(.{ .opcode = 0x74 }); // JE
    try vcode.finishBlock(bb0, &[_]BlockIndex{ 1, 2 });

    // Block 1 -> Block 3
    const bb1 = try vcode.startBlock(&.{});
    _ = try vcode.addInst(.{ .opcode = 0x90 });
    try vcode.finishBlock(bb1, &[_]BlockIndex{3});

    // Block 2 -> Block 3
    const bb2 = try vcode.startBlock(&.{});
    _ = try vcode.addInst(.{ .opcode = 0x90 });
    try vcode.finishBlock(bb2, &[_]BlockIndex{3});

    // Block 3 (exit)
    const bb3 = try vcode.startBlock(&.{});
    _ = try vcode.addInst(.{ .opcode = 0xC3 }); // RET
    try vcode.finishBlock(bb3, &.{});

    try vcode.computePreds();

    try testing.expectEqual(@as(usize, 4), vcode.numBlocks());

    // Check successors.
    const b0 = vcode.getBlock(0);
    try testing.expectEqual(@as(usize, 2), b0.succs.len);
    try testing.expectEqual(@as(BlockIndex, 1), b0.succs[0]);
    try testing.expectEqual(@as(BlockIndex, 2), b0.succs[1]);

    // Check predecessors.
    const b3 = vcode.getBlock(3);
    try testing.expectEqual(@as(usize, 2), b3.preds.len);
    try testing.expectEqual(@as(BlockIndex, 1), b3.preds[0]);
    try testing.expectEqual(@as(BlockIndex, 2), b3.preds[1]);
}

/// VReg renaming map for SSA construction and optimization.
pub const VRegRenameMap = struct {
    map: std.AutoHashMap(VReg, VReg),
    allocator: Allocator,

    pub fn init(allocator: Allocator) VRegRenameMap {
        return .{
            .map = std.AutoHashMap(VReg, VReg).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *VRegRenameMap) void {
        self.map.deinit();
    }

    /// Add a rename from old to new vreg.
    pub fn addRename(self: *VRegRenameMap, old: VReg, new: VReg) !void {
        try self.map.put(old, new);
    }

    /// Get the renamed vreg, or original if not renamed.
    pub fn getRename(self: *const VRegRenameMap, vreg: VReg) VReg {
        return self.map.get(vreg) orelse vreg;
    }

    /// Check if vreg has been renamed.
    pub fn isRenamed(self: *const VRegRenameMap, vreg: VReg) bool {
        return self.map.contains(vreg);
    }
};

test "VCode with block parameters" {
    const TestInst = struct { opcode: u8 };

    var vcode = VCode(TestInst).init(testing.allocator);
    defer vcode.deinit();

    const params = [_]VReg{
        VReg.new(0, .int),
        VReg.new(1, .int),
    };

    const bb0 = try vcode.startBlock(&params);
    _ = try vcode.addInst(.{ .opcode = 0x90 });
    try vcode.finishBlock(bb0, &.{});

    const block = vcode.getBlock(bb0);
    try testing.expectEqual(@as(usize, 2), block.params.len);
    try testing.expectEqual(@as(u32, 0), block.params[0].index());
    try testing.expectEqual(@as(u32, 1), block.params[1].index());
}

test "VRegRenameMap basic" {
    var rename_map = VRegRenameMap.init(testing.allocator);
    defer rename_map.deinit();

    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const v3 = VReg.new(3, .int);

    try rename_map.addRename(v1, v2);

    try testing.expect(rename_map.isRenamed(v1));
    try testing.expect(!rename_map.isRenamed(v3));

    const renamed = rename_map.getRename(v1);
    try testing.expectEqual(@as(u32, 2), renamed.index());

    const not_renamed = rename_map.getRename(v3);
    try testing.expectEqual(@as(u32, 3), not_renamed.index());
}
