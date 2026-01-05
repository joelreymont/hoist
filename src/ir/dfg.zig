const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const types = @import("types.zig");
const entities = @import("entities.zig");
const value_list = @import("value_list.zig");
const instruction_data = @import("instruction_data.zig");
const opcodes = @import("opcodes.zig");
const immediates = @import("immediates.zig");
const maps = @import("../foundation/maps.zig");

const Type = types.Type;
const Block = entities.Block;
const Inst = entities.Inst;
const Value = entities.Value;
const ValueList = value_list.ValueList;
const ValueListPool = value_list.ValueListPool;
const InstructionData = instruction_data.InstructionData;
const Opcode = opcodes.Opcode;
const Imm64 = immediates.Imm64;
const PrimaryMap = maps.PrimaryMap;
const SecondaryMap = maps.SecondaryMap;

/// Value definition - where a value comes from.
pub const ValueDef = union(enum) {
    /// Value is n'th result of instruction
    result: struct { inst: Inst, index: usize },
    /// Value is n'th parameter to block
    param: struct { block: Block, index: usize },
    /// Value is union of two values (for egraph)
    @"union": struct { x: Value, y: Value },

    pub fn unwrapInst(self: ValueDef) Inst {
        return switch (self) {
            .result => |r| r.inst,
            else => unreachable,
        };
    }

    pub fn inst(self: ValueDef) ?Inst {
        return switch (self) {
            .result => |r| r.inst,
            else => null,
        };
    }

    pub fn block(self: ValueDef) ?Block {
        return switch (self) {
            .param => |p| p.block,
            else => null,
        };
    }
};

/// Value data - packed representation of value definition.
///
/// Layout (64 bits):
/// | tag:2 | type:14 | x:24 | y:24 |
///
/// Inst:   00  ty  num   inst
/// Param:  01  ty  num   block
/// Alias:  10  ty  0     original
/// Union:  11  ty  x     y
pub const ValueData = packed struct {
    raw: u64,

    const TAG_BITS = 2;
    const TYPE_BITS = 14;
    const X_BITS = 24;
    const Y_BITS = 24;

    const TAG_SHIFT = 62;
    const TYPE_SHIFT = 48;
    const X_SHIFT = 24;
    const Y_SHIFT = 0;

    const TAG_INST: u64 = 0;
    const TAG_PARAM: u64 = 1;
    const TAG_ALIAS: u64 = 2;
    const TAG_UNION: u64 = 3;

    const X_MAX = (1 << X_BITS) - 1;
    const Y_MAX = (1 << Y_BITS) - 1;

    fn encodeNarrow(x: u32, bits: u8) u32 {
        const max = (@as(u32, 1) << @as(u5, @intCast(bits))) - 1;
        if (x == 0xffffffff) return max;
        std.debug.assert(x < max);
        return x;
    }

    fn decodeNarrow(x: u32, bits: u8) u32 {
        if (x == (@as(u32, 1) << @as(u5, @intCast(bits))) - 1) return 0xffffffff;
        return x;
    }

    pub fn inst(ty: Type, num: u16, i: Inst) ValueData {
        const x = encodeNarrow(@intCast(num), X_BITS);
        const y = encodeNarrow(i.index, Y_BITS);
        const raw = (TAG_INST << TAG_SHIFT) | (@as(u64, ty.raw) << TYPE_SHIFT) | (@as(u64, x) << X_SHIFT) | (@as(u64, y) << Y_SHIFT);
        return .{ .raw = raw };
    }

    pub fn param(ty: Type, num: u16, b: Block) ValueData {
        const x = encodeNarrow(@intCast(num), X_BITS);
        const y = encodeNarrow(b.index, Y_BITS);
        const raw = (TAG_PARAM << TAG_SHIFT) | (@as(u64, ty.raw) << TYPE_SHIFT) | (@as(u64, x) << X_SHIFT) | (@as(u64, y) << Y_SHIFT);
        return .{ .raw = raw };
    }

    pub fn alias(ty: Type, original: Value) ValueData {
        const y = encodeNarrow(original.index, Y_BITS);
        const raw = (TAG_ALIAS << TAG_SHIFT) | (@as(u64, ty.raw) << TYPE_SHIFT) | (@as(u64, y) << Y_SHIFT);
        return .{ .raw = raw };
    }

    pub fn @"union"(ty: Type, x: Value, y: Value) ValueData {
        const x_enc = encodeNarrow(x.index, X_BITS);
        const y_enc = encodeNarrow(y.index, Y_BITS);
        const raw = (TAG_UNION << TAG_SHIFT) | (@as(u64, ty.raw) << TYPE_SHIFT) | (@as(u64, x_enc) << X_SHIFT) | (@as(u64, y_enc) << Y_SHIFT);
        return .{ .raw = raw };
    }

    pub fn getType(self: ValueData) Type {
        const ty_bits: u16 = @intCast((self.raw >> TYPE_SHIFT) & ((1 << TYPE_BITS) - 1));
        return .{ .raw = ty_bits };
    }

    pub fn setType(self: *ValueData, ty: Type) void {
        const mask = ~(@as(u64, (1 << TYPE_BITS) - 1) << TYPE_SHIFT);
        self.raw = (self.raw & mask) | (@as(u64, ty.raw) << TYPE_SHIFT);
    }

    pub fn toDef(self: ValueData) ValueDef {
        const tag = self.raw >> TAG_SHIFT;
        const x_raw: u32 = @intCast((self.raw >> X_SHIFT) & X_MAX);
        const y_raw: u32 = @intCast((self.raw >> Y_SHIFT) & Y_MAX);

        return switch (tag) {
            TAG_INST => .{ .result = .{
                .inst = Inst.new(decodeNarrow(y_raw, Y_BITS)),
                .index = decodeNarrow(x_raw, X_BITS),
            } },
            TAG_PARAM => .{ .param = .{
                .block = Block.new(decodeNarrow(y_raw, Y_BITS)),
                .index = decodeNarrow(x_raw, X_BITS),
            } },
            TAG_UNION => .{ .@"union" = .{
                .x = Value.new(decodeNarrow(x_raw, X_BITS)),
                .y = Value.new(decodeNarrow(y_raw, Y_BITS)),
            } },
            else => unreachable,
        };
    }

    pub fn isAlias(self: ValueData) bool {
        return (self.raw >> TAG_SHIFT) == TAG_ALIAS;
    }

    pub fn aliasOriginal(self: ValueData) ?Value {
        if (!self.isAlias()) return null;
        const y_raw: u32 = @intCast((self.raw >> Y_SHIFT) & Y_MAX);
        return Value.new(decodeNarrow(y_raw, Y_BITS));
    }
};

/// Basic block data.
pub const BlockData = struct {
    params: ValueList,

    pub fn init() BlockData {
        return .{ .params = ValueList.default() };
    }

    pub fn getParams(self: BlockData, pool: *const ValueListPool) []const Value {
        return pool.asSlice(self.params);
    }
};

test "ValueData inst" {
    const data = ValueData.inst(Type.I32, 0, Inst.new(42));
    try testing.expectEqual(Type.I32, data.getType());
    const def = data.toDef();
    try testing.expectEqual(Inst.new(42), def.result.inst);
    try testing.expectEqual(0, def.result.index);
}

test "ValueData param" {
    const data = ValueData.param(Type.I64, 1, Block.new(10));
    try testing.expectEqual(Type.I64, data.getType());
    const def = data.toDef();
    try testing.expectEqual(Block.new(10), def.param.block);
    try testing.expectEqual(1, def.param.index);
}

test "ValueData alias" {
    const data = ValueData.alias(Type.I32, Value.new(100));
    try testing.expect(data.isAlias());
    try testing.expectEqual(Value.new(100), data.aliasOriginal().?);
}

test "ValueData union" {
    const data = ValueData.@"union"(Type.I32, Value.new(1), Value.new(2));
    const def = data.toDef();
    try testing.expectEqual(Value.new(1), def.@"union".x);
    try testing.expectEqual(Value.new(2), def.@"union".y);
}

test "BlockData" {
    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit();

    var block = BlockData.init();
    try pool.push(&block.params, Value.new(1));
    try pool.push(&block.params, Value.new(2));

    const params = block.getParams(&pool);
    try testing.expectEqual(2, params.len);
    try testing.expectEqual(Value.new(1), params[0]);
    try testing.expectEqual(Value.new(2), params[1]);
}

test "ValueDef unwrapInst" {
    const def = ValueDef{ .result = .{ .inst = Inst.new(42), .index = 0 } };
    try testing.expectEqual(Inst.new(42), def.unwrapInst());
    try testing.expectEqual(Inst.new(42), def.inst().?);
}

/// Data flow graph - SSA value definitions and instructions.
pub const DataFlowGraph = struct {
    insts: PrimaryMap(Inst, InstructionData),
    results: SecondaryMap(Inst, ValueList),
    values: SecondaryMap(Value, ValueData),
    blocks: PrimaryMap(Block, BlockData),
    value_lists: ValueListPool,

    const Self = @This();

    pub fn init(allocator: Allocator) DataFlowGraph {
        return .{
            .insts = PrimaryMap(Inst, InstructionData).init(allocator),
            .results = SecondaryMap(Inst, ValueList).init(allocator),
            .values = SecondaryMap(Value, ValueData).init(allocator),
            .blocks = PrimaryMap(Block, BlockData).init(allocator),
            .value_lists = ValueListPool.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.insts.deinit();
        self.results.deinit();
        self.values.deinit();
        self.blocks.deinit();
        self.value_lists.deinit();
    }

    pub fn makeInst(self: *Self, data: InstructionData) !Inst {
        return try self.insts.push(data);
    }

    /// Create a binary instruction with the given opcode, result type, and arguments.
    /// Returns the result value.
    pub fn makeBinary(self: *Self, opcode: Opcode, ty: Type, arg0: Value, arg1: Value) !Value {
        const inst_data = instruction_data.BinaryData.init(opcode, arg0, arg1);
        const inst = try self.makeInst(.{ .binary = inst_data });
        return try self.appendInstResult(inst, ty);
    }

    /// Create a unary instruction with the given opcode, result type, and argument.
    /// Returns the result value.
    pub fn makeUnary(self: *Self, opcode: Opcode, ty: Type, arg: Value) !Value {
        const inst_data = instruction_data.UnaryData.init(opcode, arg);
        const inst = try self.makeInst(.{ .unary = inst_data });
        return try self.appendInstResult(inst, ty);
    }

    /// Create an iconst instruction with the given immediate value.
    /// Type is inferred as i64.
    /// Returns the constant value.
    pub fn makeConst(self: *Self, imm: i64) !Value {
        const inst_data = instruction_data.UnaryImmData.init(.iconst, Imm64.new(imm));
        const inst = try self.makeInst(.{ .unary_imm = inst_data });
        return try self.appendInstResult(inst, Type.I64);
    }

    /// Create an integer comparison instruction.
    /// Returns the comparison result value (i1).
    pub fn makeIntCompare(self: *Self, cond: instruction_data.IntCC, arg0: Value, arg1: Value) !Value {
        const inst_data = instruction_data.IntCompareData.init(.icmp, cond, arg0, arg1);
        const inst = try self.makeInst(.{ .int_compare = inst_data });
        return try self.appendInstResult(inst, Type.I1);
    }

    pub fn appendInstResult(self: *Self, inst: Inst, ty: Type) !Value {
        const results_list = try self.results.getOrDefault(inst);
        const num: u16 = @intCast(self.value_lists.len(results_list.*));
        const val_idx = self.values.elems.items.len;
        const value_data = try self.values.getOrDefault(Value.new(val_idx));
        const val = Value.new(val_idx);
        value_data.* = ValueData.inst(ty, num, inst);
        try self.value_lists.push(results_list, val);
        return val;
    }

    pub fn instResults(self: *const Self, inst: Inst) []const Value {
        const list = self.results.get(inst) orelse return &.{};
        return self.value_lists.asSlice(list.*);
    }

    pub fn firstResult(self: *const Self, inst: Inst) ?Value {
        const results = self.instResults(inst);
        if (results.len == 0) return null;
        return results[0];
    }

    pub fn numResults(self: *const Self, inst: Inst) usize {
        return self.instResults(inst).len;
    }

    /// Get block parameters as a slice.
    pub fn blockParams(self: *const Self, block: Block) []const Value {
        const block_data = self.blocks.get(block) orelse return &.{};
        return block_data.getParams(&self.value_lists);
    }

    /// Add a new block and return its handle.
    pub fn addBlock(self: *Self) !Block {
        return try self.blocks.push(BlockData.init());
    }

    /// Alias for addBlock - used in some E2E tests.
    pub fn makeBlock(self: *Self) !Block {
        return try self.addBlock();
    }

    /// Set block parameters from types.
    pub fn setBlockParams(self: *Self, block: Block, params: []const Type) !void {
        const block_data = self.blocks.getMut(block) orelse return error.InvalidBlock;

        for (params, 0..) |ty, i| {
            const val_idx = self.values.elems.items.len;
            const value_data = try self.values.getOrDefault(Value.new(val_idx));
            value_data.* = ValueData.param(ty, @intCast(i), block);
            const val = Value.new(val_idx);
            try self.value_lists.push(&block_data.params, val);
        }
    }

    /// Append a single parameter to a block.
    pub fn appendBlockParam(self: *Self, block: Block, ty: Type) !Value {
        const block_data = self.blocks.getMut(block) orelse return error.InvalidBlock;
        const param_num = self.value_lists.len(block_data.params);

        const val_idx = self.values.elems.items.len;
        const value_data = try self.values.getOrDefault(Value.new(val_idx));
        value_data.* = ValueData.param(ty, @intCast(param_num), block);
        const val = Value.new(val_idx);
        try self.value_lists.push(&block_data.params, val);
        return val;
    }

    pub fn resolveAliases(self: *const Self, val: Value) Value {
        var current = val;
        while (self.values.get(current)) |data| {
            if (data.aliasOriginal()) |original| {
                current = original;
            } else {
                break;
            }
        }
        return current;
    }

    pub fn valueType(self: *const Self, val: Value) ?Type {
        const canonical = self.resolveAliases(val);
        const data = self.values.get(canonical) orelse return null;
        return data.getType();
    }

    /// Get the type of an instruction's first result value.
    pub fn instResultType(self: *const Self, inst: Inst) ?Type {
        const result_val = self.firstResult(inst) orelse return null;
        return self.valueType(result_val);
    }

    pub fn valueDef(self: *const Self, val: Value) ?ValueDef {
        const canonical = self.resolveAliases(val);
        const data = self.values.get(canonical) orelse return null;
        return data.toDef();
    }

    pub fn setValueType(self: *Self, val: Value, ty: Type) void {
        const canonical = self.resolveAliases(val);
        if (self.values.getMut(canonical)) |data| {
            data.setType(ty);
        }
    }

    pub fn resolveAllAliases(self: *Self) void {
        for (self.insts.elems.items) |*inst_data| {
            switch (inst_data.*) {
                .unary => |*data| {
                    data.arg = self.resolveAliases(data.arg);
                },
                .binary => |*data| {
                    data.args[0] = self.resolveAliases(data.args[0]);
                    data.args[1] = self.resolveAliases(data.args[1]);
                },
                .int_compare => |*data| {
                    data.args[0] = self.resolveAliases(data.args[0]);
                    data.args[1] = self.resolveAliases(data.args[1]);
                },
                .float_compare => |*data| {
                    data.args[0] = self.resolveAliases(data.args[0]);
                    data.args[1] = self.resolveAliases(data.args[1]);
                },
                .branch => |*data| {
                    data.condition = self.resolveAliases(data.condition);
                },
                .branch_table => |*data| {
                    data.arg = self.resolveAliases(data.arg);
                },
                .call => |*data| {
                    const slice = self.value_lists.asMutSlice(data.args);
                    for (slice) |*val| {
                        val.* = self.resolveAliases(val.*);
                    }
                },
                .call_indirect => |*data| {
                    const slice = self.value_lists.asMutSlice(data.args);
                    for (slice) |*val| {
                        val.* = self.resolveAliases(val.*);
                    }
                },
                .load => |*data| {
                    data.arg = self.resolveAliases(data.arg);
                },
                .store => |*data| {
                    data.args[0] = self.resolveAliases(data.args[0]);
                    data.args[1] = self.resolveAliases(data.args[1]);
                },
                .ternary => |*data| {
                    data.args[0] = self.resolveAliases(data.args[0]);
                    data.args[1] = self.resolveAliases(data.args[1]);
                    data.args[2] = self.resolveAliases(data.args[2]);
                },
                .ternary_imm8 => |*data| {
                    data.args[0] = self.resolveAliases(data.args[0]);
                    data.args[1] = self.resolveAliases(data.args[1]);
                },
                .shuffle => |*data| {
                    data.args[0] = self.resolveAliases(data.args[0]);
                    data.args[1] = self.resolveAliases(data.args[1]);
                },
                .unary_with_trap => |*data| {
                    data.arg = self.resolveAliases(data.arg);
                },
                .extract_lane => |*data| {
                    data.arg = self.resolveAliases(data.arg);
                },
                .atomic_load => |*data| {
                    data.addr = self.resolveAliases(data.addr);
                },
                .atomic_store => |*data| {
                    data.addr = self.resolveAliases(data.addr);
                    data.src = self.resolveAliases(data.src);
                },
                .atomic_rmw => |*data| {
                    data.addr = self.resolveAliases(data.addr);
                    data.src = self.resolveAliases(data.src);
                },
                .atomic_cas => |*data| {
                    data.addr = self.resolveAliases(data.addr);
                    data.expected = self.resolveAliases(data.expected);
                    data.replacement = self.resolveAliases(data.replacement);
                },
                .jump, .nullary, .unary_imm, .fence => {},
            }
        }
    }

    /// Replace all uses of a value with another value.
    /// Walks all instructions and updates operands.
    pub fn replaceAllUses(self: *Self, old_value: Value, new_value: Value) !void {
        const block_call = @import("block_call.zig");

        for (self.insts.elems.items) |*inst_data| {
            switch (inst_data.*) {
                .unary => |*data| {
                    if (std.meta.eql(data.arg, old_value)) {
                        data.arg = new_value;
                    }
                },
                .binary => |*data| {
                    if (std.meta.eql(data.args[0], old_value)) {
                        data.args[0] = new_value;
                    }
                    if (std.meta.eql(data.args[1], old_value)) {
                        data.args[1] = new_value;
                    }
                },
                .int_compare => |*data| {
                    if (std.meta.eql(data.args[0], old_value)) {
                        data.args[0] = new_value;
                    }
                    if (std.meta.eql(data.args[1], old_value)) {
                        data.args[1] = new_value;
                    }
                },
                .float_compare => |*data| {
                    if (std.meta.eql(data.args[0], old_value)) {
                        data.args[0] = new_value;
                    }
                    if (std.meta.eql(data.args[1], old_value)) {
                        data.args[1] = new_value;
                    }
                },
                .branch => |*data| {
                    const slice = self.value_lists.asMutSlice(data.destination.values);
                    if (slice.len > 1) {
                        var i: usize = 1;
                        while (i < slice.len) : (i += 1) {
                            var v: Value = undefined;
                            var index: u32 = undefined;
                            const tag = block_call.BlockArg.decodeFromValue(slice[i], &v, &index);
                            if (tag == .value and std.meta.eql(v, old_value)) {
                                slice[i] = block_call.BlockArg.fromValue(new_value).encodeAsValue(new_value, 0);
                            }
                        }
                    }
                },
                .branch_table => |*data| {
                    if (std.meta.eql(data.arg, old_value)) {
                        data.arg = new_value;
                    }
                },
                .call => |*data| {
                    const slice = self.value_lists.asMutSlice(data.args);
                    for (slice) |*val| {
                        if (std.meta.eql(val.*, old_value)) {
                            val.* = new_value;
                        }
                    }
                },
                .call_indirect => |*data| {
                    const slice = self.value_lists.asMutSlice(data.args);
                    for (slice) |*val| {
                        if (std.meta.eql(val.*, old_value)) {
                            val.* = new_value;
                        }
                    }
                },
                .load => |*data| {
                    if (std.meta.eql(data.arg, old_value)) {
                        data.arg = new_value;
                    }
                },
                .store => |*data| {
                    if (std.meta.eql(data.args[0], old_value)) {
                        data.args[0] = new_value;
                    }
                    if (std.meta.eql(data.args[1], old_value)) {
                        data.args[1] = new_value;
                    }
                },
                .jump, .nullary => {},
            }
        }
    }
};

test "DataFlowGraph makeInst" {
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    const data = instruction_data.BinaryData.init(.iadd, Value.new(1), Value.new(2));
    const inst = try dfg.makeInst(.{ .binary = data });
    try testing.expectEqual(Inst.new(0), inst);
}

test "DataFlowGraph append result" {
    var dfg = DataFlowGraph.init(testing.allocator);
    defer dfg.deinit();

    const data = instruction_data.BinaryData.init(.iadd, Value.new(1), Value.new(2));
    const inst = try dfg.makeInst(.{ .binary = data });

    const result = try dfg.appendInstResult(inst, Type.I32);
    try testing.expectEqual(Value.new(0), result);
    try testing.expectEqual(@as(usize, 1), dfg.numResults(inst));
    try testing.expectEqual(result, dfg.firstResult(inst).?);
}
