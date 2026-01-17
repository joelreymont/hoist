const std = @import("std");
const testing = std.testing;

const root = @import("../root.zig");
const entities = @import("entities.zig");
const value_list = @import("value_list.zig");

const Block = entities.Block;
const Value = entities.Value;
const ValueList = value_list.ValueList;
const ValueListPool = value_list.ValueListPool;

/// Block argument - sum type for branch instruction arguments.
///
/// Can be:
/// - Ordinary Value
/// - TryCallRet - return value from try_call (with index)
/// - TryCallExn - exception payload from try_call (with index)
///
/// Encoded as Value in pool using top 2 bits as tag.
pub const BlockArg = enum(u2) {
    value = 0,
    try_call_ret = 1,
    try_call_exn = 2,

    const TAG_BITS = 2;
    const TAG_SHIFT = 30;
    const PAYLOAD_MASK: u32 = (1 << TAG_SHIFT) - 1;

    /// Create ordinary value argument.
    pub fn fromValue(v: Value) BlockArg {
        _ = v;
        return .value;
    }

    /// Create try_call return value argument.
    pub fn tryCallRet(index: u32) BlockArg {
        _ = index;
        return .try_call_ret;
    }

    /// Create try_call exception argument.
    pub fn tryCallExn(index: u32) BlockArg {
        _ = index;
        return .try_call_exn;
    }

    /// Encode as Value for storage in pool.
    pub fn encodeAsValue(self: BlockArg, v: Value, index: u32) Value {
        const tag: u32 = @intFromEnum(self);
        const payload: u32 = switch (self) {
            .value => v.asBits(),
            .try_call_ret, .try_call_exn => index,
        };
        std.debug.assert(payload < (1 << TAG_SHIFT));
        const raw = (tag << TAG_SHIFT) | payload;
        return Value.fromBits(raw);
    }

    /// Decode from Value.
    pub fn decodeFromValue(v: Value, out_value: *Value, out_index: *u32) BlockArg {
        const raw = v.asU32();
        const tag: u2 = @intCast(raw >> TAG_SHIFT);
        const payload = raw & PAYLOAD_MASK;

        const result: BlockArg = @enumFromInt(tag);
        switch (result) {
            .value => out_value.* = Value.fromBits(payload),
            .try_call_ret, .try_call_exn => out_index.* = payload,
        }
        return result;
    }

    pub fn format(self: BlockArg, writer: anytype, v: Value, index: u32) !void {
        switch (self) {
            .value => try writer.print("{f}", .{v}),
            .try_call_ret => try writer.print("ret{d}", .{index}),
            .try_call_exn => try writer.print("exn{d}", .{index}),
        }
    }
};

/// Block with arguments for branch instructions.
///
/// Stores block + args in single ValueList:
/// - First element: block encoded as Value
/// - Remaining elements: BlockArg encoded as Value
pub const BlockCall = struct {
    values: ValueList,

    fn valueToBlock(v: Value) Block {
        return Block.fromU32(v.asU32());
    }

    fn blockToValue(b: Block) Value {
        return Value.fromU32(b.asU32());
    }

    /// Create BlockCall with block and arguments.
    pub fn new(blk: Block, args: []const Value, pool: *ValueListPool) !BlockCall {
        var values = ValueList.default();
        try pool.push(&values, blockToValue(blk));

        for (args) |arg| {
            const encoded = BlockArg.fromValue(arg).encodeAsValue(arg, 0);
            try pool.push(&values, encoded);
        }

        return .{ .values = values };
    }

    /// Get block for this call.
    pub fn block(self: BlockCall, pool: *const ValueListPool) Block {
        const v = pool.first(self.values) orelse unreachable;
        return valueToBlock(v);
    }

    /// Set block for this call.
    pub fn setBlock(self: *BlockCall, b: Block, pool: *ValueListPool) void {
        const v = blockToValue(b);
        if (pool.getMut(self.values, 0)) |ptr| {
            ptr.* = v;
        }
    }

    /// Append argument to call.
    pub fn appendArg(self: *BlockCall, arg: Value, pool: *ValueListPool) !void {
        const encoded = BlockArg.fromValue(arg).encodeAsValue(arg, 0);
        try pool.push(&self.values, encoded);
    }

    /// Get number of arguments.
    pub fn len(self: BlockCall, pool: *const ValueListPool) usize {
        const total = pool.len(self.values);
        if (total == 0) return 0;
        return total - 1;
    }

    /// Get argument at index.
    pub fn getArg(self: BlockCall, pool: *const ValueListPool, idx: usize) ?Value {
        const encoded = pool.get(self.values, idx + 1) orelse return null;
        var v: Value = undefined;
        var index: u32 = undefined;
        const tag = BlockArg.decodeFromValue(encoded, &v, &index);
        return switch (tag) {
            .value => v,
            else => null,
        };
    }

    /// Clear arguments (keep block).
    pub fn clear(self: *BlockCall, pool: *ValueListPool) !void {
        try pool.truncate(&self.values, 1);
    }

    /// Deep clone in same pool.
    pub fn deepClone(self: BlockCall, pool: *ValueListPool) !BlockCall {
        const cloned = try pool.deepClone(self.values);
        return .{ .values = cloned };
    }

    pub fn format(self: BlockCall, writer: anytype, pool: *const ValueListPool) !void {
        try writer.print("{f}", .{self.block(pool)});
        const arg_count = self.len(pool);
        if (arg_count > 0) {
            try writer.writeAll("(");
            var i: usize = 0;
            while (i < arg_count) : (i += 1) {
                if (i > 0) try writer.writeAll(", ");
                if (self.getArg(pool, i)) |v| {
                    try writer.print("{f}", .{v});
                }
            }
            try writer.writeAll(")");
        }
    }
};

test "BlockArg encoding" {
    const v = Value.new(42);
    const arg = BlockArg.fromValue(v);
    const encoded = arg.encodeAsValue(v, 0);

    var decoded_v: Value = undefined;
    var decoded_idx: u32 = undefined;
    const decoded = BlockArg.decodeFromValue(encoded, &decoded_v, &decoded_idx);

    try testing.expectEqual(BlockArg.value, decoded);
    try testing.expectEqual(v, decoded_v);
}

test "BlockArg try_call_ret" {
    const arg = BlockArg.tryCallRet(5);
    const encoded = arg.encodeAsValue(Value.new(0), 5);

    var v: Value = undefined;
    var idx: u32 = undefined;
    const decoded = BlockArg.decodeFromValue(encoded, &v, &idx);

    try testing.expectEqual(BlockArg.try_call_ret, decoded);
    try testing.expectEqual(@as(u32, 5), idx);
}

test "BlockCall basic" {
    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit();

    const b = Block.new(10);
    const args = [_]Value{ Value.new(1), Value.new(2) };
    var call = try BlockCall.new(b, &args, &pool);

    try testing.expectEqual(b, call.block(&pool));
    try testing.expectEqual(@as(usize, 2), call.len(&pool));
    try testing.expectEqual(Value.new(1), call.getArg(&pool, 0).?);
    try testing.expectEqual(Value.new(2), call.getArg(&pool, 1).?);
}

test "BlockCall append" {
    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit();

    const b = Block.new(5);
    var call = try BlockCall.new(b, &.{}, &pool);

    try call.appendArg(Value.new(100), &pool);
    try testing.expectEqual(@as(usize, 1), call.len(&pool));
    try testing.expectEqual(Value.new(100), call.getArg(&pool, 0).?);
}

test "BlockCall clear" {
    var pool = ValueListPool.init(testing.allocator);
    defer pool.deinit();

    const b = Block.new(7);
    const args = [_]Value{ Value.new(1), Value.new(2), Value.new(3) };
    var call = try BlockCall.new(b, &args, &pool);

    try call.clear(&pool);
    try testing.expectEqual(@as(usize, 0), call.len(&pool));
    try testing.expectEqual(b, call.block(&pool));
}
