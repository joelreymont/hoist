const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const signature = @import("signature.zig");
const dfg_mod = @import("dfg.zig");
const layout_mod = @import("layout.zig");
const entities = @import("entities.zig");
const stack_slot_data = @import("stack_slot_data.zig");
const global_value_data = @import("global_value_data.zig");
const jump_table_data = @import("jump_table_data.zig");
const maps = @import("../foundation/maps.zig");

const Signature = signature.Signature;
const DataFlowGraph = dfg_mod.DataFlowGraph;
const Layout = layout_mod.Layout;
const Block = entities.Block;
const StackSlot = entities.StackSlot;
const GlobalValue = entities.GlobalValue;
const JumpTable = entities.JumpTable;
const StackSlotData = stack_slot_data.StackSlotData;
const GlobalValueData = global_value_data.GlobalValueData;
const JumpTableData = jump_table_data.JumpTableData;
const PrimaryMap = maps.PrimaryMap;

/// Function - a unit of code with signature, blocks, instructions, and data.
pub const Function = struct {
    /// Function name for debugging.
    name: []const u8,
    /// Function signature.
    sig: Signature,
    /// Data flow graph with instructions and values.
    dfg: DataFlowGraph,
    /// Block and instruction layout.
    layout: Layout,
    /// Stack slot allocations.
    stack_slots: PrimaryMap(StackSlot, StackSlotData),
    /// Global value definitions.
    global_values: PrimaryMap(GlobalValue, GlobalValueData),
    /// Jump table definitions.
    jump_tables: PrimaryMap(JumpTable, JumpTableData),

    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, name: []const u8, sig: Signature) !Self {
        const name_copy = try allocator.dupe(u8, name);
        return .{
            .name = name_copy,
            .sig = sig,
            .dfg = DataFlowGraph.init(allocator),
            .layout = Layout.init(allocator),
            .stack_slots = PrimaryMap(StackSlot, StackSlotData).init(allocator),
            .global_values = PrimaryMap(GlobalValue, GlobalValueData).init(allocator),
            .jump_tables = PrimaryMap(JumpTable, JumpTableData).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.dfg.deinit();
        self.layout.deinit();
        self.stack_slots.deinit();
        self.global_values.deinit();

        // Jump tables contain ArrayLists
        for (self.jump_tables.elems.items) |*jt| {
            jt.deinit();
        }
        self.jump_tables.deinit();
    }

    pub fn entryBlock(self: *const Self) ?Block {
        return self.layout.entryBlock();
    }

    pub fn isLeaf(self: *const Self) bool {
        // A leaf function has no calls
        var iter = self.layout.blockIter();
        while (iter.next()) |blk| {
            var inst_iter = self.layout.blockInsts(blk);
            while (inst_iter.next()) |inst| {
                const inst_data = self.dfg.insts.get(inst) orelse continue;
                switch (inst_data.*) {
                    .call, .call_indirect => return false,
                    else => {},
                }
            }
        }
        return true;
    }

    pub fn format(self: Self, writer: anytype) !void {
        try writer.print("function \"{}\" {{\n", .{self.name});
        try writer.print("  signature: {}\n", .{self.sig});
        try writer.print("  blocks: {}\n", .{self.layout.blocks.elems.items.len});
        try writer.print("  insts: {}\n", .{self.dfg.insts.elems.items.len});
        try writer.print("  stack_slots: {}\n", .{self.stack_slots.elems.items.len});
        try writer.print("  global_values: {}\n", .{self.global_values.elems.items.len});
        try writer.print("  jump_tables: {}\n", .{self.jump_tables.elems.items.len});
        try writer.writeAll("}");
    }
};

test "Function init" {
    const sig = try Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test_func", sig);
    defer func.deinit();

    try testing.expectEqualStrings("test_func", func.name);
    try testing.expect(func.entryBlock() == null);
    try testing.expect(func.isLeaf());
}

test "Function entryBlock" {
    const sig = try Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const block = Block.new(0);
    try func.layout.appendBlock(block);

    try testing.expectEqual(block, func.entryBlock().?);
}
