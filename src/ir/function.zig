const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
pub const signature = @import("signature.zig");
const dfg_mod = @import("dfg.zig");
const layout_mod = @import("layout.zig");
const entities = @import("entities.zig");
const stack_slot_data = @import("stack_slot_data.zig");
const global_value_data = @import("global_value_data.zig");
const jump_table_data = @import("jump_table_data.zig");
const func_metadata_mod = @import("func_metadata.zig");
const cfg_mod = @import("cfg.zig");
const types = @import("types.zig");
const maps = @import("../foundation/maps.zig");

const Signature = signature.Signature;
const DataFlowGraph = dfg_mod.DataFlowGraph;
const Layout = layout_mod.Layout;
const Block = entities.Block;
const Inst = entities.Inst;
const StackSlot = entities.StackSlot;
const GlobalValue = entities.GlobalValue;
const JumpTable = entities.JumpTable;
const StackSlotData = stack_slot_data.StackSlotData;
const GlobalValueData = global_value_data.GlobalValueData;
const JumpTableData = jump_table_data.JumpTableData;
const PrimaryMap = maps.PrimaryMap;
const SigRef = entities.SigRef;
const FuncMetadataTable = func_metadata_mod.FuncMetadataTable;
const ControlFlowGraph = cfg_mod.ControlFlowGraph;
const StructStore = types.StructStore;

/// Function - a unit of code with signature, blocks, instructions, and data.
pub const Function = struct {
    /// Function name for debugging.
    name: []const u8,
    /// Function signature.
    sig: Signature,
    /// Data flow graph with instructions and values.
    dfg: DataFlowGraph,
    /// Struct type storage for this function.
    struct_store: StructStore,
    /// Block and instruction layout.
    layout: Layout,
    /// Stack slot allocations.
    stack_slots: PrimaryMap(StackSlot, StackSlotData),
    /// Global value definitions.
    global_values: PrimaryMap(GlobalValue, GlobalValueData),
    /// Jump table definitions.
    jump_tables: PrimaryMap(JumpTable, JumpTableData),
    /// Cached control flow graph (optional, computed on demand).
    cfg: ?ControlFlowGraph,
    /// Signature references used in this function (for calls, etc).
    signatures: PrimaryMap(SigRef, Signature),
    /// External function metadata (for try_call, call, etc).
    func_metadata: FuncMetadataTable,

    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, name: []const u8, sig: Signature) !Self {
        const name_copy = try allocator.dupe(u8, name);
        return .{
            .name = name_copy,
            .sig = sig,
            .dfg = DataFlowGraph.init(allocator),
            .struct_store = StructStore.init(allocator),
            .layout = Layout.init(allocator),
            .stack_slots = PrimaryMap(StackSlot, StackSlotData).init(allocator),
            .global_values = PrimaryMap(GlobalValue, GlobalValueData).init(allocator),
            .jump_tables = PrimaryMap(JumpTable, JumpTableData).init(allocator),
            .signatures = PrimaryMap(SigRef, Signature).init(allocator),
            .func_metadata = FuncMetadataTable.init(allocator),
            .cfg = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.dfg.deinit();
        self.struct_store.deinit();
        self.layout.deinit();
        self.stack_slots.deinit();
        self.global_values.deinit();

        // Jump tables contain ArrayLists
        for (self.jump_tables.elems.items) |*jt| {
            jt.deinit();
        }
        self.jump_tables.deinit();

        // Signatures need deinit for their params/returns
        for (self.signatures.elems.items) |*sig| {
            sig.deinit();
        }
        self.signatures.deinit();

        // Main function signature
        self.sig.deinit();

        // Function metadata
        self.func_metadata.deinit();

        if (self.cfg) |*cfg| {
            cfg.deinit(self.allocator);
        }
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

    /// Delete an instruction from the layout and DFG.
    /// Caller must ensure all uses of its results are removed.
    pub fn deleteInst(self: *Self, inst: Inst) !void {
        self.layout.removeInst(inst);
        try self.dfg.deleteInst(inst);
    }

    /// Delete a block and all instructions within it.
    pub fn deleteBlock(self: *Self, block: Block) !void {
        var insts = std.ArrayList(Inst){};
        defer insts.deinit(self.allocator);

        var inst_iter = self.layout.blockInsts(block);
        while (inst_iter.next()) |inst| {
            try insts.append(self.allocator, inst);
        }

        for (insts.items) |inst| {
            try self.deleteInst(inst);
        }

        self.layout.removeBlock(block);
    }

    pub fn format(self: Self, writer: anytype) !void {
        try writer.print("function \"{}\" {{\n", .{self.name});
        try writer.print("  signature: {}\n", .{self.sig});
        try writer.print("  blocks: {}\n", .{self.layout.blocks.elems.items.len});
        try writer.print("  insts: {}\n", .{self.dfg.liveInstCount()});
        try writer.print("  stack_slots: {}\n", .{self.stack_slots.elems.items.len});
        try writer.print("  global_values: {}\n", .{self.global_values.elems.items.len});
        try writer.print("  jump_tables: {}\n", .{self.jump_tables.elems.items.len});
        try writer.writeAll("}");
    }
};

test "Function init" {
    const sig = Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test_func", sig);
    defer func.deinit();

    try testing.expectEqualStrings("test_func", func.name);
    try testing.expect(func.entryBlock() == null);
    try testing.expect(func.isLeaf());
}

test "Function entryBlock" {
    const sig = Signature.init(testing.allocator, .fast);
    var func = try Function.init(testing.allocator, "test", sig);
    defer func.deinit();

    const block = Block.new(0);
    try func.layout.appendBlock(block);

    try testing.expectEqual(block, func.entryBlock().?);
}
