const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const Value = root.entities.Value;
const Inst = root.entities.Inst;

/// Stack map entry - location of a live value at a safepoint.
pub const StackMapEntry = struct {
    /// Value being tracked.
    value: Value,
    /// Location kind.
    location: Location,

    pub const Location = union(enum) {
        /// Value in register.
        register: u8,
        /// Value on stack at offset.
        stack: i32,
        /// Constant value.
        constant: i64,
    };
};

/// Stack map for a safepoint (e.g., function call, GC point).
pub const StackMap = struct {
    /// Instruction this stackmap is attached to.
    inst: Inst,
    /// Live values and their locations.
    entries: std.ArrayList(StackMapEntry),

    allocator: Allocator,

    pub fn init(allocator: Allocator, inst: Inst) StackMap {
        return .{
            .inst = inst,
            .entries = std.ArrayList(StackMapEntry){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StackMap) void {
        self.entries.deinit();
    }

    /// Add entry for value in register.
    pub fn addRegister(self: *StackMap, value: Value, reg: u8) !void {
        try self.entries.append(.{
            .value = value,
            .location = .{ .register = reg },
        });
    }

    /// Add entry for value on stack.
    pub fn addStack(self: *StackMap, value: Value, offset: i32) !void {
        try self.entries.append(.{
            .value = value,
            .location = .{ .stack = offset },
        });
    }

    /// Add entry for constant value.
    pub fn addConstant(self: *StackMap, value: Value, constant: i64) !void {
        try self.entries.append(.{
            .value = value,
            .location = .{ .constant = constant },
        });
    }
};

test "StackMap init" {
    const inst = Inst.new(0);
    var stackmap = StackMap.init(testing.allocator, inst);
    defer stackmap.deinit();

    try testing.expectEqual(inst, stackmap.inst);
    try testing.expectEqual(@as(usize, 0), stackmap.entries.items.len);
}

test "StackMap addRegister" {
    const inst = Inst.new(0);
    var stackmap = StackMap.init(testing.allocator, inst);
    defer stackmap.deinit();

    const val = Value.new(1);
    try stackmap.addRegister(val, 5);

    try testing.expectEqual(@as(usize, 1), stackmap.entries.items.len);
    try testing.expectEqual(val, stackmap.entries.items[0].value);
    try testing.expectEqual(@as(u8, 5), stackmap.entries.items[0].location.register);
}

test "StackMap addStack" {
    const inst = Inst.new(0);
    var stackmap = StackMap.init(testing.allocator, inst);
    defer stackmap.deinit();

    const val = Value.new(2);
    try stackmap.addStack(val, -16);

    try testing.expectEqual(@as(usize, 1), stackmap.entries.items.len);
    try testing.expectEqual(val, stackmap.entries.items[0].value);
    try testing.expectEqual(@as(i32, -16), stackmap.entries.items[0].location.stack);
}

test "StackMap addConstant" {
    const inst = Inst.new(0);
    var stackmap = StackMap.init(testing.allocator, inst);
    defer stackmap.deinit();

    const val = Value.new(3);
    try stackmap.addConstant(val, 42);

    try testing.expectEqual(@as(usize, 1), stackmap.entries.items.len);
    try testing.expectEqual(val, stackmap.entries.items[0].value);
    try testing.expectEqual(@as(i64, 42), stackmap.entries.items[0].location.constant);
}
