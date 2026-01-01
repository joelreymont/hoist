const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const entities = @import("entities.zig");
const maps = @import("../foundation/maps.zig");

const Block = entities.Block;
const Inst = entities.Inst;
const SecondaryMap = maps.SecondaryMap;

/// Block node in layout's linked list.
pub const BlockNode = struct {
    prev_block: ?Block = null,
    next_block: ?Block = null,
    first_inst: ?Inst = null,
    last_inst: ?Inst = null,

    pub fn init() BlockNode {
        return .{};
    }

    pub fn format(self: BlockNode, writer: anytype) !void {
        try writer.print("BlockNode{{ prev={?}, next={?}, first={?}, last={?} }}", .{
            self.prev_block,
            self.next_block,
            self.first_inst,
            self.last_inst,
        });
    }
};

/// Instruction node in layout's linked list.
pub const InstNode = struct {
    prev_inst: ?Inst = null,
    next_inst: ?Inst = null,
    block: ?Block = null,

    pub fn init() InstNode {
        return .{};
    }

    pub fn format(self: InstNode, writer: anytype) !void {
        try writer.print("InstNode{{ prev={?}, next={?}, block={?} }}", .{
            self.prev_inst,
            self.next_inst,
            self.block,
        });
    }
};

test "BlockNode init" {
    const node = BlockNode.init();
    try testing.expect(node.prev_block == null);
    try testing.expect(node.next_block == null);
    try testing.expect(node.first_inst == null);
    try testing.expect(node.last_inst == null);
}

/// Layout - block and instruction ordering.
pub const Layout = struct {
    first_block: ?Block = null,
    last_block: ?Block = null,
    blocks: SecondaryMap(Block, BlockNode),
    insts: SecondaryMap(Inst, InstNode),

    const Self = @This();

    pub fn init(allocator: Allocator) Layout {
        return .{
            .blocks = SecondaryMap(Block, BlockNode).init(allocator),
            .insts = SecondaryMap(Inst, InstNode).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.blocks.deinit();
        self.insts.deinit();
    }

    pub fn clear(self: *Self) void {
        self.first_block = null;
        self.last_block = null;
        self.blocks.clear();
        self.insts.clear();
    }

    pub fn isBlockInserted(self: *const Self, blk: Block) bool {
        return self.blocks.get(blk) != null;
    }

    pub fn appendBlock(self: *Self, blk: Block) !void {
        const node = try self.blocks.getOrDefault(blk);
        node.prev_block = self.last_block;
        node.next_block = null;

        if (self.last_block) |last| {
            const last_node = try self.blocks.getOrDefault(last);
            last_node.next_block = blk;
        } else {
            self.first_block = blk;
        }
        self.last_block = blk;
    }

    pub fn insertBlockBefore(self: *Self, blk: Block, before: Block) !void {
        const before_node = try self.blocks.getOrDefault(before);
        const node = try self.blocks.getOrDefault(blk);

        node.prev_block = before_node.prev_block;
        node.next_block = before;

        if (before_node.prev_block) |prev| {
            const prev_node = try self.blocks.getOrDefault(prev);
            prev_node.next_block = blk;
        } else {
            self.first_block = blk;
        }
        before_node.prev_block = blk;
    }

    pub fn insertBlockAfter(self: *Self, blk: Block, after: Block) !void {
        const after_node = try self.blocks.getOrDefault(after);
        const node = try self.blocks.getOrDefault(blk);

        node.prev_block = after;
        node.next_block = after_node.next_block;

        if (after_node.next_block) |next| {
            const next_node = try self.blocks.getOrDefault(next);
            next_node.prev_block = blk;
        } else {
            self.last_block = blk;
        }
        after_node.next_block = blk;
    }

    pub fn removeBlock(self: *Self, blk: Block) void {
        const node = self.blocks.getMut(blk) orelse return;

        if (node.prev_block) |prev| {
            const prev_node = self.blocks.getMut(prev).?;
            prev_node.next_block = node.next_block;
        } else {
            self.first_block = node.next_block;
        }

        if (node.next_block) |next| {
            const next_node = self.blocks.getMut(next).?;
            next_node.prev_block = node.prev_block;
        } else {
            self.last_block = node.prev_block;
        }

        node.prev_block = null;
        node.next_block = null;
    }

    pub fn appendInst(self: *Self, inst: Inst, blk: Block) !void {
        const block_node = try self.blocks.getOrDefault(blk);
        const node = try self.insts.getOrDefault(inst);

        node.block = blk;
        node.prev_inst = block_node.last_inst;
        node.next_inst = null;

        if (block_node.last_inst) |last| {
            const last_node = try self.insts.getOrDefault(last);
            last_node.next_inst = inst;
        } else {
            block_node.first_inst = inst;
        }
        block_node.last_inst = inst;
    }

    pub fn insertInstBefore(self: *Self, inst: Inst, before: Inst) !void {
        const before_node = try self.insts.getOrDefault(before);
        const blk = before_node.block orelse return error.InstNotInserted;

        const node = try self.insts.getOrDefault(inst);
        node.block = blk;
        node.prev_inst = before_node.prev_inst;
        node.next_inst = before;

        if (before_node.prev_inst) |prev| {
            const prev_node = try self.insts.getOrDefault(prev);
            prev_node.next_inst = inst;
        } else {
            const block_node = try self.blocks.getOrDefault(blk);
            block_node.first_inst = inst;
        }
        before_node.prev_inst = inst;
    }

    pub fn insertInstAfter(self: *Self, inst: Inst, after: Inst) !void {
        const after_node = try self.insts.getOrDefault(after);
        const blk = after_node.block orelse return error.InstNotInserted;

        const node = try self.insts.getOrDefault(inst);
        node.block = blk;
        node.prev_inst = after;
        node.next_inst = after_node.next_inst;

        if (after_node.next_inst) |next| {
            const next_node = try self.insts.getOrDefault(next);
            next_node.prev_inst = inst;
        } else {
            const block_node = try self.blocks.getOrDefault(blk);
            block_node.last_inst = inst;
        }
        after_node.next_inst = inst;
    }

    pub fn removeInst(self: *Self, inst: Inst) void {
        const node = self.insts.getMut(inst) orelse return;
        const blk = node.block orelse return;

        if (node.prev_inst) |prev| {
            const prev_node = self.insts.getMut(prev).?;
            prev_node.next_inst = node.next_inst;
        } else {
            const block_node = self.blocks.getMut(blk).?;
            block_node.first_inst = node.next_inst;
        }

        if (node.next_inst) |next| {
            const next_node = self.insts.getMut(next).?;
            next_node.prev_inst = node.prev_inst;
        } else {
            const block_node = self.blocks.getMut(blk).?;
            block_node.last_inst = node.prev_inst;
        }

        node.prev_inst = null;
        node.next_inst = null;
        node.block = null;
    }

    pub fn instBlock(self: *const Self, inst: Inst) ?Block {
        const node = self.insts.get(inst) orelse return null;
        return node.block;
    }

    pub fn entryBlock(self: *const Self) ?Block {
        return self.first_block;
    }

    pub const BlockIter = struct {
        layout: *const Layout,
        current: ?Block,

        pub fn next(self: *BlockIter) ?Block {
            const blk = self.current orelse return null;
            if (self.layout.blocks.get(blk)) |node| {
                self.current = node.next_block;
            }
            return blk;
        }
    };

    pub fn blockIter(self: *const Self) BlockIter {
        return .{ .layout = self, .current = self.first_block };
    }

    pub const InstIter = struct {
        layout: *const Layout,
        current: ?Inst,

        pub fn next(self: *InstIter) ?Inst {
            const inst = self.current orelse return null;
            if (self.layout.insts.get(inst)) |node| {
                self.current = node.next_inst;
            }
            return inst;
        }
    };

    pub fn blockInsts(self: *const Self, blk: Block) InstIter {
        const first_inst = if (self.blocks.get(blk)) |node| node.first_inst else null;
        return .{ .layout = self, .current = first_inst };
    }
};

test "InstNode init" {
    const node = InstNode.init();
    try testing.expect(node.prev_inst == null);
    try testing.expect(node.next_inst == null);
    try testing.expect(node.block == null);
}

test "Layout init" {
    var layout = Layout.init(testing.allocator);
    defer layout.deinit();

    try testing.expect(layout.first_block == null);
    try testing.expect(layout.last_block == null);
}

test "Layout appendBlock" {
    var layout = Layout.init(testing.allocator);
    defer layout.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);

    try layout.appendBlock(b0);
    try testing.expectEqual(b0, layout.first_block.?);
    try testing.expectEqual(b0, layout.last_block.?);

    try layout.appendBlock(b1);
    try testing.expectEqual(b0, layout.first_block.?);
    try testing.expectEqual(b1, layout.last_block.?);
}

test "Layout block iteration" {
    var layout = Layout.init(testing.allocator);
    defer layout.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    try layout.appendBlock(b0);
    try layout.appendBlock(b1);
    try layout.appendBlock(b2);

    var iter = layout.blockIter();
    try testing.expectEqual(b0, iter.next().?);
    try testing.expectEqual(b1, iter.next().?);
    try testing.expectEqual(b2, iter.next().?);
    try testing.expect(iter.next() == null);
}

test "Layout appendInst" {
    var layout = Layout.init(testing.allocator);
    defer layout.deinit();

    const b0 = Block.new(0);
    const inst0 = Inst.new(0);
    const inst1 = Inst.new(1);

    try layout.appendBlock(b0);
    try layout.appendInst(inst0, b0);
    try layout.appendInst(inst1, b0);

    try testing.expectEqual(b0, layout.instBlock(inst0).?);
    try testing.expectEqual(b0, layout.instBlock(inst1).?);

    var iter = layout.blockInsts(b0);
    try testing.expectEqual(inst0, iter.next().?);
    try testing.expectEqual(inst1, iter.next().?);
    try testing.expect(iter.next() == null);
}

test "Layout removeBlock" {
    var layout = Layout.init(testing.allocator);
    defer layout.deinit();

    const b0 = Block.new(0);
    const b1 = Block.new(1);
    const b2 = Block.new(2);

    try layout.appendBlock(b0);
    try layout.appendBlock(b1);
    try layout.appendBlock(b2);

    layout.removeBlock(b1);

    var iter = layout.blockIter();
    try testing.expectEqual(b0, iter.next().?);
    try testing.expectEqual(b2, iter.next().?);
    try testing.expect(iter.next() == null);
}

test "Layout entryBlock" {
    var layout = Layout.init(testing.allocator);
    defer layout.deinit();

    try testing.expect(layout.entryBlock() == null);

    const b0 = Block.new(0);
    try layout.appendBlock(b0);

    try testing.expectEqual(b0, layout.entryBlock().?);
}
