const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const types = @import("regalloc2/types.zig");
const VReg = types.VReg;

/// Register liveness information for a block.
pub const BlockLiveness = struct {
    /// Live-in set - registers live at block entry.
    live_in: std.AutoHashMap(VReg, void),
    /// Live-out set - registers live at block exit.
    live_out: std.AutoHashMap(VReg, void),
    allocator: Allocator,

    pub fn init(allocator: Allocator) BlockLiveness {
        return .{
            .live_in = std.AutoHashMap(VReg, void).init(allocator),
            .live_out = std.AutoHashMap(VReg, void).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BlockLiveness) void {
        self.live_in.deinit();
        self.live_out.deinit();
    }

    pub fn addLiveIn(self: *BlockLiveness, vreg: VReg) !void {
        try self.live_in.put(vreg, {});
    }

    pub fn addLiveOut(self: *BlockLiveness, vreg: VReg) !void {
        try self.live_out.put(vreg, {});
    }

    pub fn isLiveIn(self: *const BlockLiveness, vreg: VReg) bool {
        return self.live_in.contains(vreg);
    }

    pub fn isLiveOut(self: *const BlockLiveness, vreg: VReg) bool {
        return self.live_out.contains(vreg);
    }
};

/// Liveness analysis for virtual registers.
pub const Liveness = struct {
    /// Liveness per block (indexed by block ID).
    blocks: std.ArrayList(BlockLiveness),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Liveness {
        return .{
            .blocks = std.ArrayList(BlockLiveness).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Liveness) void {
        for (self.blocks.items) |*block| {
            block.deinit();
        }
        self.blocks.deinit();
    }

    /// Add block liveness info.
    pub fn addBlock(self: *Liveness) !usize {
        const block_liveness = BlockLiveness.init(self.allocator);
        try self.blocks.append(block_liveness);
        return self.blocks.items.len - 1;
    }

    /// Get liveness for a block.
    pub fn getBlock(self: *Liveness, block_id: usize) ?*BlockLiveness {
        if (block_id >= self.blocks.items.len) return null;
        return &self.blocks.items[block_id];
    }

    /// Check if vreg is live at block entry.
    pub fn isLiveIn(self: *const Liveness, block_id: usize, vreg: VReg) bool {
        if (block_id >= self.blocks.items.len) return false;
        return self.blocks.items[block_id].isLiveIn(vreg);
    }

    /// Check if vreg is live at block exit.
    pub fn isLiveOut(self: *const Liveness, block_id: usize, vreg: VReg) bool {
        if (block_id >= self.blocks.items.len) return false;
        return self.blocks.items[block_id].isLiveOut(vreg);
    }
};

test "BlockLiveness live-in" {
    var liveness = BlockLiveness.init(testing.allocator);
    defer liveness.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);

    try liveness.addLiveIn(v1);

    try testing.expect(liveness.isLiveIn(v1));
    try testing.expect(!liveness.isLiveIn(v2));
}

test "BlockLiveness live-out" {
    var liveness = BlockLiveness.init(testing.allocator);
    defer liveness.deinit();

    const v1 = VReg.new(1);
    const v2 = VReg.new(2);

    try liveness.addLiveOut(v1);
    try liveness.addLiveOut(v2);

    try testing.expect(liveness.isLiveOut(v1));
    try testing.expect(liveness.isLiveOut(v2));
}

test "Liveness addBlock" {
    var liveness = Liveness.init(testing.allocator);
    defer liveness.deinit();

    const b0 = try liveness.addBlock();
    const b1 = try liveness.addBlock();

    try testing.expectEqual(@as(usize, 0), b0);
    try testing.expectEqual(@as(usize, 1), b1);
    try testing.expectEqual(@as(usize, 2), liveness.blocks.items.len);
}

test "Liveness getBlock" {
    var liveness = Liveness.init(testing.allocator);
    defer liveness.deinit();

    const b0 = try liveness.addBlock();
    const block = liveness.getBlock(b0).?;

    const v1 = VReg.new(5);
    try block.addLiveIn(v1);

    try testing.expect(liveness.isLiveIn(b0, v1));
}

test "Liveness isLiveIn/isLiveOut" {
    var liveness = Liveness.init(testing.allocator);
    defer liveness.deinit();

    const b0 = try liveness.addBlock();
    const v1 = VReg.new(10);
    const v2 = VReg.new(20);

    const block = liveness.getBlock(b0).?;
    try block.addLiveIn(v1);
    try block.addLiveOut(v2);

    try testing.expect(liveness.isLiveIn(b0, v1));
    try testing.expect(!liveness.isLiveIn(b0, v2));
    try testing.expect(!liveness.isLiveOut(b0, v1));
    try testing.expect(liveness.isLiveOut(b0, v2));
}
