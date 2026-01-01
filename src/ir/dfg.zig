//! Data flow graph tracking Instructions, Values, and blocks.

const std = @import("std");
const entity = @import("../foundation/entity.zig");
const entities = @import("entities.zig");
const instructions = @import("instructions.zig");
const types = @import("types.zig");

const Allocator = std.mem.Allocator;
const Value = entities.Value;
const Block = entities.Block;
const Inst = entities.Inst;
const Type = types.Type;
const InstructionData = instructions.InstructionData;
const ValueList = instructions.ValueList;
const ValueListPool = instructions.ValueListPool;

/// Storage for instructions within the DFG.
pub const Insts = struct {
    map: entity.PrimaryMap(Inst, InstructionData),

    pub fn init(allocator: Allocator) Insts {
        return .{ .map = entity.PrimaryMap(Inst, InstructionData).init(allocator) };
    }

    pub fn deinit(self: *Insts) void {
        self.map.deinit();
    }

    pub fn get(self: *const Insts, inst: Inst) ?*const InstructionData {
        return self.map.get(inst);
    }

    pub fn getMut(self: *Insts, inst: Inst) ?*InstructionData {
        return self.map.getMut(inst);
    }
};

/// Data associated with a basic block.
pub const BlockData = struct {
    /// Block parameters (phi node inputs).
    params: ValueList,

    pub fn init() BlockData {
        return .{ .params = ValueList{} };
    }
};

/// Storage for basic blocks within the DFG.
pub const Blocks = struct {
    map: entity.PrimaryMap(Block, BlockData),

    pub fn init(allocator: Allocator) Blocks {
        return .{ .map = entity.PrimaryMap(Block, BlockData).init(allocator) };
    }

    pub fn deinit(self: *Blocks) void {
        self.map.deinit();
    }

    /// Create a new basic block.
    pub fn add(self: *Blocks) !Block {
        return try self.map.push(BlockData.init());
    }

    pub fn get(self: *const Blocks, block: Block) ?*const BlockData {
        return self.map.get(block);
    }

    pub fn getMut(self: *Blocks, block: Block) ?*BlockData {
        return self.map.getMut(block);
    }

    pub fn len(self: *const Blocks) usize {
        return self.map.len();
    }

    pub fn isValid(self: *const Blocks, block: Block) bool {
        return self.map.isValid(block);
    }
};

/// Where did a value come from?
pub const ValueDef = union(enum) {
    /// Value is the n'th result of an instruction.
    result: struct { inst: Inst, num: usize },
    /// Value is the n'th parameter to a block.
    param: struct { block: Block, num: usize },
    /// Value is an alias of another value.
    alias: Value,
    /// Value is a union of two other values (aegraph representation).
    @"union": struct { x: Value, y: Value },

    /// Unwrap the instruction where the value was defined, or return null.
    pub fn inst(self: ValueDef) ?Inst {
        return switch (self) {
            .result => |r| r.inst,
            else => null,
        };
    }

    /// Unwrap the block where the parameter is defined, or return null.
    pub fn block(self: ValueDef) ?Block {
        return switch (self) {
            .param => |p| p.block,
            else => null,
        };
    }

    /// Get the number component of this definition (index of the result/param).
    pub fn num(self: ValueDef) usize {
        return switch (self) {
            .result => |r| r.num,
            .param => |p| p.num,
            else => 0,
        };
    }
};

/// Internal table storage for values.
/// This is a bit-packed representation that fits in 64 bits:
///
/// Layout:
///   | tag:2 | type:14 | x:24 | y:24 |
///
/// Inst:   tag=00, ty, output_num, inst_index
/// Param:  tag=01, ty, param_num, block_index
/// Alias:  tag=10, ty, 0, value_index
/// Union:  tag=11, ty, first_value, second_value
pub const ValueData = struct {
    packed: u64,

    const TAG_INST: u64 = 0;
    const TAG_PARAM: u64 = 1;
    const TAG_ALIAS: u64 = 2;
    const TAG_UNION: u64 = 3;

    const TAG_SHIFT: u6 = 62;
    const TYPE_SHIFT: u6 = 48;
    const X_SHIFT: u6 = 24;
    const Y_SHIFT: u6 = 0;

    const TYPE_MASK: u64 = (1 << 14) - 1;
    const X_MASK: u64 = (1 << 24) - 1;
    const Y_MASK: u64 = (1 << 24) - 1;

    fn make(tag: u64, ty: Type, x: u32, y: u32) ValueData {
        std.debug.assert(tag < 4);
        const ty_bits = @intFromEnum(ty);
        std.debug.assert(ty_bits < (1 << 14));

        return .{
            .packed = (tag << TAG_SHIFT) |
                (@as(u64, ty_bits) << TYPE_SHIFT) |
                (@as(u64, x) << X_SHIFT) |
                (@as(u64, y) << Y_SHIFT),
        };
    }

    pub fn inst(ty: Type, num: u16, inst_val: Inst) ValueData {
        return make(TAG_INST, ty, num, @intFromEnum(inst_val));
    }

    pub fn param(ty: Type, num: u16, block_val: Block) ValueData {
        return make(TAG_PARAM, ty, num, @intFromEnum(block_val));
    }

    pub fn alias(ty: Type, original: Value) ValueData {
        return make(TAG_ALIAS, ty, 0, @intFromEnum(original));
    }

    pub fn @"union"(ty: Type, x: Value, y: Value) ValueData {
        return make(TAG_UNION, ty, @intFromEnum(x), @intFromEnum(y));
    }

    pub fn ty(self: ValueData) Type {
        const ty_bits: u16 = @truncate((self.packed >> TYPE_SHIFT) & TYPE_MASK);
        return @enumFromInt(ty_bits);
    }

    pub fn tag(self: ValueData) u2 {
        return @truncate(self.packed >> TAG_SHIFT);
    }

    pub fn toDef(self: ValueData) ValueDef {
        const x: u32 = @truncate((self.packed >> X_SHIFT) & X_MASK);
        const y: u32 = @truncate((self.packed >> Y_SHIFT) & Y_MASK);

        return switch (self.tag()) {
            TAG_INST => .{ .result = .{ .inst = @enumFromInt(y), .num = x } },
            TAG_PARAM => .{ .param = .{ .block = @enumFromInt(y), .num = x } },
            TAG_ALIAS => .{ .alias = @enumFromInt(y) },
            TAG_UNION => .{ .@"union" = .{ .x = @enumFromInt(x), .y = @enumFromInt(y) } },
            else => unreachable,
        };
    }
};

/// A data flow graph defines all instructions and basic blocks in a function as well as
/// the data flow dependencies between them. The DFG also tracks values which can be either
/// instruction results or block parameters.
pub const DataFlowGraph = struct {
    allocator: Allocator,

    /// Data about all instructions in the function.
    insts: Insts,

    /// List of result values for each instruction.
    results: entity.SecondaryMap(Inst, ValueList),

    /// Basic blocks in the function and their parameters.
    blocks: Blocks,

    /// Memory pool of value lists.
    value_lists: ValueListPool,

    /// Primary value table with entries for all values.
    values: entity.PrimaryMap(Value, ValueData),

    pub fn init(allocator: Allocator) DataFlowGraph {
        return .{
            .allocator = allocator,
            .insts = Insts.init(allocator),
            .results = entity.SecondaryMap(Inst, ValueList).init(allocator, ValueList{}),
            .blocks = Blocks.init(allocator),
            .value_lists = ValueListPool.init(),
            .values = entity.PrimaryMap(Value, ValueData).init(allocator),
        };
    }

    pub fn deinit(self: *DataFlowGraph) void {
        self.insts.deinit();
        self.results.deinit();
        self.blocks.deinit();
        self.value_lists.deinit(self.allocator);
        self.values.deinit();
    }

    /// Create a new basic block.
    pub fn makeBlock(self: *DataFlowGraph) !Block {
        return try self.blocks.add();
    }

    /// Append a parameter to a block.
    pub fn appendBlockParam(self: *DataFlowGraph, block: Block, ty: Type) !Value {
        const block_data = self.blocks.getMut(block) orelse return error.InvalidBlock;
        const num = block_data.params.len(&self.value_lists);

        const value = try self.values.push(ValueData.param(ty, @intCast(num), block));
        try block_data.params.push(value, &self.value_lists);
        return value;
    }

    /// Get the block parameters.
    pub fn blockParams(self: *const DataFlowGraph, block: Block) ?[]const Value {
        const block_data = self.blocks.get(block) orelse return null;
        return block_data.params.asSlice(&self.value_lists);
    }

    /// Create a new instruction.
    pub fn makeInst(self: *DataFlowGraph, data: InstructionData) !Inst {
        const inst = try self.insts.map.push(data);
        try self.results.set(inst, ValueList{});
        return inst;
    }

    /// Append a result to an instruction.
    pub fn appendInstResult(self: *DataFlowGraph, inst: Inst, ty: Type) !Value {
        const result_list = self.results.getMut(inst) orelse return error.InvalidInst;
        const num = result_list.len(&self.value_lists);

        const value = try self.values.push(ValueData.inst(ty, @intCast(num), inst));
        try result_list.push(value, &self.value_lists);
        return value;
    }

    /// Get the results of an instruction.
    pub fn instResults(self: *const DataFlowGraph, inst: Inst) ?[]const Value {
        const result_list = self.results.get(inst) orelse return null;
        return result_list.asSlice(&self.value_lists);
    }

    /// Get the value definition (where the value came from).
    pub fn valueDef(self: *const DataFlowGraph, value: Value) ?ValueDef {
        const data = self.values.get(value) orelse return null;
        return data.toDef();
    }

    /// Get the type of a value.
    pub fn valueType(self: *const DataFlowGraph, value: Value) ?Type {
        const data = self.values.get(value) orelse return null;
        return data.ty();
    }

    /// Resolve any aliases to get the original value.
    pub fn resolveAliases(self: *const DataFlowGraph, value: Value) Value {
        var current = value;
        while (self.valueDef(current)) |def| {
            switch (def) {
                .alias => |original| current = original,
                else => break,
            }
        }
        return current;
    }

    /// Turn a value into an alias of another.
    pub fn changeToAlias(self: *DataFlowGraph, dest: Value, src: Value) !void {
        const original = self.resolveAliases(src);
        std.debug.assert(@intFromEnum(dest) != @intFromEnum(original));

        const ty = self.valueType(original) orelse return error.InvalidValue;
        try self.values.set(dest, ValueData.alias(ty, original));
    }
};

test "DataFlowGraph basic" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var dfg = DataFlowGraph.init(allocator);
    defer dfg.deinit();

    // Create a block
    const block0 = try dfg.makeBlock();
    try testing.expect(dfg.blocks.isValid(block0));

    // Add a parameter
    const param0 = try dfg.appendBlockParam(block0, Type.i32);
    try testing.expectEqual(Type.i32, dfg.valueType(param0));

    const def = dfg.valueDef(param0).?;
    try testing.expectEqual(block0, def.param.block);
    try testing.expectEqual(@as(usize, 0), def.param.num);

    // Create an instruction
    const inst_data = InstructionData{
        .binary = .{
            .opcode = .iadd,
            .args = .{ param0, param0 },
        },
    };
    const inst0 = try dfg.makeInst(inst_data);

    // Add a result
    const result0 = try dfg.appendInstResult(inst0, Type.i32);
    try testing.expectEqual(Type.i32, dfg.valueType(result0));

    const result_def = dfg.valueDef(result0).?;
    try testing.expectEqual(inst0, result_def.result.inst);
    try testing.expectEqual(@as(usize, 0), result_def.result.num);
}

test "ValueData packing" {
    const testing = std.testing;

    const inst_data = ValueData.inst(Type.i64, 2, entities.Inst.fromIndex(42));
    try testing.expectEqual(Type.i64, inst_data.ty());
    const def = inst_data.toDef();
    try testing.expectEqual(@as(usize, 2), def.result.num);
    try testing.expectEqual(entities.Inst.fromIndex(42), def.result.inst);

    const param_data = ValueData.param(Type.f32, 1, entities.Block.fromIndex(5));
    try testing.expectEqual(Type.f32, param_data.ty());
    const param_def = param_data.toDef();
    try testing.expectEqual(@as(usize, 1), param_def.param.num);
    try testing.expectEqual(entities.Block.fromIndex(5), param_def.param.block);
}
