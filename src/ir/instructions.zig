//! Instruction formats and opcodes.
//!
//! The `instructions` module contains definitions for instruction formats, opcodes, and the
//! in-memory representation of IR instructions.
//!
//! This is a minimal scaffold. Full opcode definitions will be generated from meta definitions.

const std = @import("std");
const entity = @import("../foundation/entity.zig");
const entities = @import("entities.zig");

const Value = entities.Value;
const Block = entities.Block;
const Inst = entities.Inst;

/// A variable list of Value operands.
/// Some instructions use an external list of argument values because there is not enough space
/// in the InstructionData struct. These value lists are stored in a memory pool.
pub const ValueList = entity.EntityList(Value);

/// Memory pool for holding value lists.
pub const ValueListPool = entity.ListPool(Value);

/// A block argument: either an ordinary value, or a special edge-generated value
/// from try_call instructions.
pub const BlockArg = union(enum) {
    /// An ordinary value, usable at the branch instruction.
    value: Value,
    /// A return value of a try_call's called function (with index).
    try_call_ret: u32,
    /// An exception payload value of a try_call (with index).
    try_call_exn: u32,

    /// Encode this block argument as a Value for storage in the value pool.
    fn encodeAsValue(self: BlockArg) Value {
        const tag: u32, const payload: u32 = switch (self) {
            .value => |v| .{ 0, @intFromEnum(v) },
            .try_call_ret => |i| .{ 1, i },
            .try_call_exn => |i| .{ 2, i },
        };
        std.debug.assert(payload < (1 << 30));
        const raw = (tag << 30) | payload;
        return @enumFromInt(raw);
    }

    /// Decode a raw Value encoding of this block argument.
    fn decodeFromValue(v: Value) BlockArg {
        const raw = @intFromEnum(v);
        const tag = raw >> 30;
        const payload = raw & ((1 << 30) - 1);
        return switch (tag) {
            0 => .{ .value = @enumFromInt(payload) },
            1 => .{ .try_call_ret = payload },
            2 => .{ .try_call_exn = payload },
            else => unreachable,
        };
    }

    /// Return this argument as a Value, if it is one.
    pub fn asValue(self: BlockArg) ?Value {
        return switch (self) {
            .value => |v| v,
            else => null,
        };
    }

    pub fn format(
        self: BlockArg,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .value => |v| try writer.print("{}", .{v}),
            .try_call_ret => |i| try writer.print("ret{}", .{i}),
            .try_call_exn => |i| try writer.print("exn{}", .{i}),
        }
    }
};

/// A pair of a Block and its arguments, stored in a single EntityList internally.
///
/// The first element of the EntityList is always the block (encoded as a Value).
/// Subsequent entries are BlockArg values (also encoded as Values).
pub const BlockCall = struct {
    /// The underlying storage. The first element is guaranteed to be a Block encoded as a Value.
    values: ValueList,

    fn valueToBlock(val: Value) Block {
        return @enumFromInt(@intFromEnum(val));
    }

    fn blockToValue(block: Block) Value {
        return @enumFromInt(@intFromEnum(block));
    }

    /// Construct a BlockCall with the given block and arguments.
    pub fn init(
        block: Block,
        args: []const BlockArg,
        pool: *ValueListPool,
    ) !BlockCall {
        var values = ValueList{};
        try values.push(blockToValue(block), pool);
        for (args) |arg| {
            try values.push(arg.encodeAsValue(), pool);
        }
        return .{ .values = values };
    }

    /// Return the block for this BlockCall.
    pub fn block(self: BlockCall, pool: *const ValueListPool) Block {
        const val = self.values.first(pool).?;
        return valueToBlock(val);
    }

    /// Replace the block for this BlockCall.
    pub fn setBlock(self: *BlockCall, new_block: Block, pool: *ValueListPool) void {
        self.values.getMut(0, pool).?.* = blockToValue(new_block);
    }

    /// Append an argument to the block args.
    pub fn appendArgument(self: *BlockCall, arg: BlockArg, pool: *ValueListPool) !void {
        try self.values.push(arg.encodeAsValue(), pool);
    }

    /// Return the length of the argument list.
    pub fn len(self: BlockCall, pool: *const ValueListPool) usize {
        return self.values.len(pool) - 1;
    }

    /// Return the arguments as a slice (requires decoding).
    pub fn args(self: BlockCall, pool: *const ValueListPool, allocator: std.mem.Allocator) ![]BlockArg {
        const slice = self.values.asSlice(pool);
        if (slice.len <= 1) return &[_]BlockArg{};

        var result = try allocator.alloc(BlockArg, slice.len - 1);
        for (slice[1..], 0..) |val, i| {
            result[i] = BlockArg.decodeFromValue(val);
        }
        return result;
    }

    /// Deep-clone the underlying list in the same pool.
    pub fn deepClone(self: BlockCall, pool: *ValueListPool) !BlockCall {
        return .{ .values = try self.values.deepClone(pool) };
    }
};

/// Placeholder opcode enum. This will be expanded with actual opcodes.
pub const Opcode = enum(u16) {
    not_an_opcode = 0,

    // Arithmetic
    iadd,
    isub,
    imul,

    // Memory
    load,
    store,

    // Control flow
    jump,
    br_if,
    @"return",
    call,

    _,

    pub fn format(
        self: Opcode,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll(@tagName(self));
    }
};

/// Placeholder instruction format enum.
pub const InstructionFormat = enum {
    unary,
    binary,
    ternary,
    nullary,

    // Memory operations
    load,
    store,

    // Control flow
    jump,
    branch,
    call,
    @"return",
};

/// Instruction data - the in-memory representation of an instruction.
/// This is a tagged union representing all possible instruction formats.
pub const InstructionData = union(InstructionFormat) {
    unary: struct {
        opcode: Opcode,
        arg: Value,
    },
    binary: struct {
        opcode: Opcode,
        args: [2]Value,
    },
    ternary: struct {
        opcode: Opcode,
        args: [3]Value,
    },
    nullary: struct {
        opcode: Opcode,
    },
    load: struct {
        opcode: Opcode,
        addr: Value,
    },
    store: struct {
        opcode: Opcode,
        addr: Value,
        data: Value,
    },
    jump: struct {
        opcode: Opcode,
        destination: Block,
    },
    branch: struct {
        opcode: Opcode,
        condition: Value,
        then_block: Block,
        else_block: Block,
    },
    call: struct {
        opcode: Opcode,
        func: entities.FuncRef,
        args: ValueList,
    },
    @"return": struct {
        opcode: Opcode,
        args: ValueList,
    },

    /// Get the opcode for this instruction.
    pub fn opcode(self: InstructionData) Opcode {
        return switch (self) {
            inline else => |data| data.opcode,
        };
    }

    /// Get the instruction format.
    pub fn format(self: InstructionData) InstructionFormat {
        return self;
    }
};

test "BlockArg encoding" {
    const testing = std.testing;

    const v42 = entities.Value.fromIndex(42);
    const arg1 = BlockArg{ .value = v42 };
    const encoded = arg1.encodeAsValue();
    const decoded = BlockArg.decodeFromValue(encoded);

    try testing.expectEqual(BlockArg.value, @as(std.meta.Tag(BlockArg), decoded));
    try testing.expectEqual(v42, decoded.value);

    const arg2 = BlockArg{ .try_call_ret = 5 };
    const encoded2 = arg2.encodeAsValue();
    const decoded2 = BlockArg.decodeFromValue(encoded2);
    try testing.expectEqual(@as(u32, 5), decoded2.try_call_ret);
}

test "BlockCall basic" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var pool = ValueListPool.init();
    defer pool.deinit(allocator);

    const block0 = entities.Block.fromIndex(0);
    const v1 = entities.Value.fromIndex(1);
    const v2 = entities.Value.fromIndex(2);

    const args_slice = [_]BlockArg{
        .{ .value = v1 },
        .{ .value = v2 },
    };

    var bc = try BlockCall.init(block0, &args_slice, &pool);
    try testing.expectEqual(block0, bc.block(&pool));
    try testing.expectEqual(@as(usize, 2), bc.len(&pool));

    const decoded_args = try bc.args(&pool, allocator);
    defer allocator.free(decoded_args);
    try testing.expectEqual(@as(usize, 2), decoded_args.len);
    try testing.expectEqual(v1, decoded_args[0].value);
    try testing.expectEqual(v2, decoded_args[1].value);
}
