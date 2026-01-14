const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const Value = root.entities.Value;
const Type = root.ir.types.Type;

/// Constant value in the constant pool.
pub const Constant = union(enum) {
    /// Integer constant.
    int: i64,
    /// Floating-point constant.
    float: f64,
    /// Boolean constant.
    bool: bool,

    pub fn format(self: Constant, writer: anytype) !void {
        switch (self) {
            .int => |val| try writer.print("{}", .{val}),
            .float => |val| try writer.print("{d}", .{val}),
            .bool => |val| try writer.print("{}", .{val}),
        }
    }
};

/// Constant pool - manages constants used in the function.
pub const ConstantPool = struct {
    /// Map from constant to value.
    constants: std.ArrayList(ConstantEntry),
    allocator: Allocator,

    const ConstantEntry = struct {
        constant: Constant,
        value: Value,
        ty: Type,
    };

    pub fn init(allocator: Allocator) ConstantPool {
        return .{
            .constants = std.ArrayList(ConstantEntry){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ConstantPool) void {
        self.constants.deinit();
    }

    /// Add integer constant.
    pub fn addInt(self: *ConstantPool, val: i64, ty: Type) !Value {
        const constant = Constant{ .int = val };
        return self.addConstant(constant, ty);
    }

    /// Add float constant.
    pub fn addFloat(self: *ConstantPool, val: f64, ty: Type) !Value {
        const constant = Constant{ .float = val };
        return self.addConstant(constant, ty);
    }

    /// Add bool constant.
    pub fn addBool(self: *ConstantPool, val: bool, ty: Type) !Value {
        const constant = Constant{ .bool = val };
        return self.addConstant(constant, ty);
    }

    fn addConstant(self: *ConstantPool, constant: Constant, ty: Type) !Value {
        // Check if constant already exists
        for (self.constants.items) |entry| {
            if (std.meta.eql(entry.constant, constant)) {
                return entry.value;
            }
        }

        // Create new value
        const value = Value.new(self.constants.items.len);
        try self.constants.append(.{
            .constant = constant,
            .value = value,
            .ty = ty,
        });
        return value;
    }

    /// Get constant for a value.
    pub fn getConstant(self: *const ConstantPool, value: Value) ?Constant {
        for (self.constants.items) |entry| {
            if (std.meta.eql(entry.value, value)) {
                return entry.constant;
            }
        }
        return null;
    }
};

test "ConstantPool addInt" {
    var pool = ConstantPool.init(testing.allocator);
    defer pool.deinit();

    const v1 = try pool.addInt(42, Type.I32);
    const v2 = try pool.addInt(42, Type.I32); // Same constant

    // Should return same value for same constant
    try testing.expectEqual(v1, v2);
    try testing.expectEqual(@as(usize, 1), pool.constants.items.len);
}

test "ConstantPool addFloat" {
    var pool = ConstantPool.init(testing.allocator);
    defer pool.deinit();

    const v1 = try pool.addFloat(3.14, Type.F64);
    const constant = pool.getConstant(v1).?;

    try testing.expectEqual(@as(f64, 3.14), constant.float);
}

test "ConstantPool addBool" {
    var pool = ConstantPool.init(testing.allocator);
    defer pool.deinit();

    const v1 = try pool.addBool(true, Type.I1);
    const constant = pool.getConstant(v1).?;

    try testing.expectEqual(true, constant.bool);
}

test "ConstantPool deduplication" {
    var pool = ConstantPool.init(testing.allocator);
    defer pool.deinit();

    const v1 = try pool.addInt(100, Type.I64);
    const v2 = try pool.addInt(100, Type.I64);
    const v3 = try pool.addInt(200, Type.I64);

    try testing.expectEqual(v1, v2);
    try testing.expect(!std.meta.eql(v1, v3));
    try testing.expectEqual(@as(usize, 2), pool.constants.items.len);
}
