const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const vcode_mod = @import("vcode.zig");
const reg_mod = @import("reg.zig");

pub const VCode = vcode_mod.VCode;
pub const BlockIndex = vcode_mod.BlockIndex;
pub const InsnIndex = vcode_mod.InsnIndex;
pub const VReg = reg_mod.VReg;
pub const Reg = reg_mod.Reg;
pub const RegClass = reg_mod.RegClass;

/// Direction in which VCodeBuilder builds VCode.
pub const VCodeBuildDirection = enum {
    /// Backward-build pass: emit() called with instructions in reverse
    /// program order within each block.
    backward,
    /// Forward-build pass: emit() called with instructions in forward
    /// program order within each block.
    forward,
};

/// VCodeBuilder - builds VCode incrementally during lowering.
///
/// Wraps a VCode and provides higher-level APIs for instruction emission,
/// block management, and backwards emission during lowering.
///
/// Based on Cranelift's machinst/vcode.rs:VCodeBuilder.
pub fn VCodeBuilder(comptime Inst: type) type {
    return struct {
        /// In-progress VCode being built.
        vcode: VCode(Inst),

        /// Direction of instruction emission.
        direction: VCodeBuildDirection,

        /// Allocator for temporary buffers during building.
        allocator: Allocator,

        /// Current block being built (if any).
        current_block: ?BlockIndex,

        /// Instructions for current block (reversed if backward emission).
        current_block_insns: std.ArrayList(Inst),

        const Self = @This();

        /// Create a new VCodeBuilder.
        pub fn init(
            allocator: Allocator,
            direction: VCodeBuildDirection,
        ) Self {
            return .{
                .vcode = VCode(Inst).init(allocator),
                .direction = direction,
                .allocator = allocator,
                .current_block = null,
                .current_block_insns = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.current_block_insns.deinit(self.allocator);
            self.vcode.deinit();
        }

        /// Start a new basic block with the given parameters.
        pub fn startBlock(self: *Self, params: []const VReg) !BlockIndex {
            // Finish previous block if any.
            if (self.current_block) |prev_block| {
                try self.flushCurrentBlock(prev_block, &.{});
            }

            const block = try self.vcode.startBlock(params);
            self.current_block = block;
            return block;
        }

        /// Emit an instruction to the current block.
        ///
        /// If building backwards, instructions are buffered and reversed
        /// when the block is finished.
        pub fn emit(self: *Self, inst: Inst) !void {
            try self.current_block_insns.append(self.allocator, inst);
        }

        /// Finish the current block with the given successor blocks.
        pub fn finishBlock(self: *Self, successors: []const BlockIndex) !void {
            if (self.current_block) |block| {
                try self.flushCurrentBlock(block, successors);
                self.current_block = null;
            }
        }

        /// Flush buffered instructions to VCode for the current block.
        fn flushCurrentBlock(
            self: *Self,
            block: BlockIndex,
            successors: []const BlockIndex,
        ) !void {
            // Reverse instructions if backward emission.
            if (self.direction == .backward) {
                std.mem.reverse(Inst, self.current_block_insns.items);
            }

            // Add all instructions to VCode.
            for (self.current_block_insns.items) |inst| {
                _ = try self.vcode.addInst(inst);
            }

            // Finish the block in VCode.
            try self.vcode.finishBlock(block, successors);

            // Clear instruction buffer.
            self.current_block_insns.clearRetainingCapacity();
        }

        /// Set the entry block.
        pub fn setEntry(self: *Self, block: BlockIndex) void {
            self.vcode.entry = block;
        }

        /// Finish building and return the completed VCode.
        ///
        /// This consumes the builder. The VCode must be deinitialized
        /// separately by the caller.
        pub fn finish(self: *Self) !VCode(Inst) {
            // Ensure current block is flushed.
            if (self.current_block) |block| {
                try self.flushCurrentBlock(block, &.{});
                self.current_block = null;
            }

            // Compute predecessor lists.
            try self.vcode.computePreds();

            // Move VCode out (caller owns it now).
            const result = self.vcode;

            // Reset our vcode to empty (deinit won't double-free).
            self.vcode = VCode(Inst).init(self.allocator);

            return result;
        }

        /// Get number of blocks built so far.
        pub fn numBlocks(self: *const Self) usize {
            return self.vcode.numBlocks();
        }

        /// Get number of instructions built so far.
        pub fn numInsns(self: *const Self) usize {
            return self.vcode.numInsns() + self.current_block_insns.items.len;
        }
    };
}

test "VCodeBuilder forward emission" {
    const TestInst = struct { opcode: u8 };

    var builder = VCodeBuilder(TestInst).init(
        testing.allocator,
        .forward,
    );
    defer builder.deinit();

    // Create entry block.
    const bb0 = try builder.startBlock(&.{});
    try builder.emit(.{ .opcode = 0x90 }); // NOP
    try builder.emit(.{ .opcode = 0xC3 }); // RET
    try builder.finishBlock(&.{});

    builder.setEntry(bb0);

    var vcode = try builder.finish();
    defer vcode.deinit();

    try testing.expectEqual(@as(usize, 1), vcode.numBlocks());
    try testing.expectEqual(@as(usize, 2), vcode.numInsns());

    // Verify instruction order (forward).
    const insns = vcode.getBlockInsns(bb0);
    try testing.expectEqual(@as(u8, 0x90), insns[0].opcode);
    try testing.expectEqual(@as(u8, 0xC3), insns[1].opcode);
}

test "VCodeBuilder backward emission" {
    const TestInst = struct { opcode: u8 };

    var builder = VCodeBuilder(TestInst).init(
        testing.allocator,
        .backward,
    );
    defer builder.deinit();

    // Create entry block.
    const bb0 = try builder.startBlock(&.{});

    // Emit in reverse order (lowering emits backwards).
    try builder.emit(.{ .opcode = 0xC3 }); // RET (emitted first)
    try builder.emit(.{ .opcode = 0x90 }); // NOP (emitted second)

    try builder.finishBlock(&.{});
    builder.setEntry(bb0);

    var vcode = try builder.finish();
    defer vcode.deinit();

    try testing.expectEqual(@as(usize, 1), vcode.numBlocks());
    try testing.expectEqual(@as(usize, 2), vcode.numInsns());

    // Verify instruction order is reversed (NOP, then RET).
    const insns = vcode.getBlockInsns(bb0);
    try testing.expectEqual(@as(u8, 0x90), insns[0].opcode);
    try testing.expectEqual(@as(u8, 0xC3), insns[1].opcode);
}

test "VCodeBuilder multiple blocks" {
    const TestInst = struct { opcode: u8 };

    var builder = VCodeBuilder(TestInst).init(
        testing.allocator,
        .forward,
    );
    defer builder.deinit();

    // Block 0: conditional branch to 1 or 2.
    const bb0 = try builder.startBlock(&.{});
    try builder.emit(.{ .opcode = 0x74 }); // JE
    try builder.finishBlock(&[_]BlockIndex{ 1, 2 });

    // Block 1: jump to 3.
    _ = try builder.startBlock(&.{});
    try builder.emit(.{ .opcode = 0xEB }); // JMP
    try builder.finishBlock(&[_]BlockIndex{3});

    // Block 2: jump to 3.
    _ = try builder.startBlock(&.{});
    try builder.emit(.{ .opcode = 0xEB }); // JMP
    try builder.finishBlock(&[_]BlockIndex{3});

    // Block 3: return.
    _ = try builder.startBlock(&.{});
    try builder.emit(.{ .opcode = 0xC3 }); // RET
    try builder.finishBlock(&.{});

    builder.setEntry(bb0);

    var vcode = try builder.finish();
    defer vcode.deinit();

    try testing.expectEqual(@as(usize, 4), vcode.numBlocks());

    // Check successors.
    const b0 = vcode.getBlock(0);
    try testing.expectEqual(@as(usize, 2), b0.succs.len);
    try testing.expectEqual(@as(BlockIndex, 1), b0.succs[0]);
    try testing.expectEqual(@as(BlockIndex, 2), b0.succs[1]);

    // Check predecessors (should be computed by finish()).
    const b3 = vcode.getBlock(3);
    try testing.expectEqual(@as(usize, 2), b3.preds.len);
}

test "VCodeBuilder with block parameters" {
    const TestInst = struct { opcode: u8 };

    var builder = VCodeBuilder(TestInst).init(
        testing.allocator,
        .forward,
    );
    defer builder.deinit();

    // Create loop header with induction variable parameter.
    const params = [_]VReg{
        VReg.new(0, .int),
        VReg.new(1, .int),
    };

    const bb0 = try builder.startBlock(&params);
    try builder.emit(.{ .opcode = 0x90 });
    try builder.finishBlock(&.{});

    builder.setEntry(bb0);

    var vcode = try builder.finish();
    defer vcode.deinit();

    const block = vcode.getBlock(bb0);
    try testing.expectEqual(@as(usize, 2), block.params.len);
    try testing.expectEqual(@as(u32, 0), block.params[0].index());
    try testing.expectEqual(@as(u32, 1), block.params[1].index());
}
