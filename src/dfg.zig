//! Data Flow Graph - tracks instructions and values.

const std = @import("std");
const entity = @import("entity.zig");
const ir = @import("ir.zig");

const Allocator = std.mem.Allocator;
const PrimaryMap = entity.PrimaryMap;
const SecondaryMap = entity.SecondaryMap;

/// Instruction data (placeholder - will expand).
pub const InstructionData = struct {
    opcode: u16,
};

/// Value definition - where a value comes from.
pub const ValueDef = union(enum) {
    /// Result of an instruction.
    result: struct { inst: ir.Inst, index: u32 },
    /// Block parameter.
    param: struct { block: ir.Block, index: u32 },
};

/// Block data.
pub const BlockData = struct {
    // Parameters added to this block
    params: std.ArrayList(ir.Value),

    pub fn init(allocator: Allocator) BlockData {
        return .{ .params = std.ArrayList(ir.Value).init(allocator) };
    }

    pub fn deinit(self: *BlockData, allocator: Allocator) void {
        self.params.deinit(allocator);
    }
};

/// Data Flow Graph - heart of Cranelift IR.
pub const DataFlowGraph = struct {
    /// All instructions.
    insts: PrimaryMap(ir.Inst, InstructionData),
    /// All values and their definitions.
    values: PrimaryMap(ir.Value, ValueDef),
    /// All blocks.
    blocks: PrimaryMap(ir.Block, BlockData),
    
    allocator: Allocator,

    pub fn init(allocator: Allocator) DataFlowGraph {
        return .{
            .insts = PrimaryMap(ir.Inst, InstructionData).init(allocator),
            .values = PrimaryMap(ir.Value, ValueDef).init(allocator),
            .blocks = PrimaryMap(ir.Block, BlockData).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DataFlowGraph) void {
        // Deinit BlockData params
        for (self.blocks.items.items) |*block| {
            block.deinit(self.allocator);
        }
        self.insts.deinit();
        self.values.deinit();
        self.blocks.deinit();
    }

    /// Create a new block.
    pub fn makeBlock(self: *DataFlowGraph) !ir.Block {
        return try self.blocks.push(BlockData.init(self.allocator));
    }

    /// Create a new instruction.
    pub fn makeInst(self: *DataFlowGraph, data: InstructionData) !ir.Inst {
        return try self.insts.push(data);
    }

    /// Append a value as the result of an instruction.
    pub fn appendInstResult(self: *DataFlowGraph, inst: ir.Inst, index: u32) !ir.Value {
        const def = ValueDef{ .result = .{ .inst = inst, .index = index } };
        return try self.values.push(def);
    }

    /// Append a block parameter.
    pub fn appendBlockParam(self: *DataFlowGraph, block: ir.Block) !ir.Value {
        const block_data = self.blocks.atMut(block);
        const index = @as(u32, @intCast(block_data.params.items.len));
        
        const def = ValueDef{ .param = .{ .block = block, .index = index } };
        const value = try self.values.push(def);
        
        try block_data.params.append(self.allocator, value);
        return value;
    }

    /// Get the definition of a value.
    pub fn valueDef(self: DataFlowGraph, value: ir.Value) *const ValueDef {
        return self.values.at(value);
    }
};

test "DFG basic" {
    var dfg = DataFlowGraph.init(std.testing.allocator);
    defer dfg.deinit();

    const block0 = try dfg.makeBlock();
    const param0 = try dfg.appendBlockParam(block0);

    const inst0 = try dfg.makeInst(.{ .opcode = 42 });
    const result0 = try dfg.appendInstResult(inst0, 0);

    const def = dfg.valueDef(param0);
    try std.testing.expectEqual(ValueDef.param, std.meta.activeTag(def.*));
    
    const result_def = dfg.valueDef(result0);
    try std.testing.expectEqual(ValueDef.result, std.meta.activeTag(result_def.*));
}
