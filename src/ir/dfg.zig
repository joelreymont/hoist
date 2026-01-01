const std = @import("std");
const testing = std.testing;

const root = @import("../root.zig");
const types = @import("types.zig");
const entities = @import("entities.zig");
const value_list = @import("value_list.zig");

const Type = types.Type;
const Block = entities.Block;
const Inst = entities.Inst;
const Value = entities.Value;
const ValueList = value_list.ValueList;
const ValueListPool = value_list.ValueListPool;

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
        const max = (1 << bits) - 1;
        if (x == 0xffffffff) return max;
        std.debug.assert(x < max);
        return x;
    }

    fn decodeNarrow(x: u32, bits: u8) u32 {
        if (x == (1 << bits) - 1) return 0xffffffff;
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
