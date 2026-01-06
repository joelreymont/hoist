//! Data values for constant representation.
//!
//! Ported from cranelift-codegen data_value.rs.
//! DataValue represents constant values (integers, floats, vectors) for constant
//! pools and initialization data.

const std = @import("std");
const Type = @import("../ir/types.zig").Type;
const immediates = @import("../ir/immediates.zig");
const Ieee32 = immediates.Ieee32;
const Ieee64 = immediates.Ieee64;

/// Represent a data value. Where Value is an SSA reference, DataValue is the
/// type + value that would be referred to by a Value.
pub const DataValue = union(enum) {
    i8: i8,
    i16: i16,
    i32: i32,
    i64: i64,
    i128: i128,
    f16: u16, // TODO: Add Ieee16 when implemented
    f32: Ieee32,
    f64: Ieee64,
    f128: u128, // TODO: Add Ieee128 when implemented
    v128: [16]u8,
    v64: [8]u8,
    v32: [4]u8,
    v16: [2]u8,

    /// Try to cast an immediate integer to the given Cranelift Type.
    pub fn fromInteger(imm: i128, ty: Type) !DataValue {
        if (ty.eql(Type.I8)) return .{ .i8 = @truncate(imm) };
        if (ty.eql(Type.I16)) return .{ .i16 = @truncate(imm) };
        if (ty.eql(Type.I32)) return .{ .i32 = @truncate(imm) };
        if (ty.eql(Type.I64)) return .{ .i64 = @truncate(imm) };
        if (ty.eql(Type.I128)) return .{ .i128 = imm };
        return error.InvalidType;
    }

    /// Return the Cranelift IR Type for this DataValue.
    pub fn getType(self: DataValue) Type {
        return switch (self) {
            .i8 => Type.I8,
            .i16 => Type.I16,
            .i32 => Type.I32,
            .i64 => Type.I64,
            .i128 => Type.I128,
            .f16 => Type.F16,
            .f32 => Type.F32,
            .f64 => Type.F64,
            .f128 => Type.F128,
            .v128 => Type.I8X16, // Default vector type
            .v64 => Type.I8X16, // TODO: Add proper I8X8 type
            .v32 => Type.I8X16, // TODO: Add proper I8X4 type
            .v16 => Type.I8X16, // TODO: Add proper I8X2 type
        };
    }

    /// Return true if the value is a vector.
    pub fn isVector(self: DataValue) bool {
        return switch (self) {
            .v128, .v64, .v32, .v16 => true,
            else => false,
        };
    }

    /// Swap bytes for endianness conversion.
    fn swapBytes(self: DataValue) DataValue {
        return switch (self) {
            .i8 => |i| .{ .i8 = @byteSwap(i) },
            .i16 => |i| .{ .i16 = @byteSwap(i) },
            .i32 => |i| .{ .i32 = @byteSwap(i) },
            .i64 => |i| .{ .i64 = @byteSwap(i) },
            .i128 => |i| .{ .i128 = @byteSwap(i) },
            .f16 => |f| .{ .f16 = @byteSwap(f) },
            .f32 => |f| .{ .f32 = Ieee32.fromBits(@byteSwap(f.bits())) },
            .f64 => |f| .{ .f64 = Ieee64.fromBits(@byteSwap(f.bits())) },
            .f128 => |f| .{ .f128 = @byteSwap(f) },
            .v128 => |v| blk: {
                var reversed = v;
                std.mem.reverse(u8, &reversed);
                break :blk .{ .v128 = reversed };
            },
            .v64 => |v| blk: {
                var reversed = v;
                std.mem.reverse(u8, &reversed);
                break :blk .{ .v64 = reversed };
            },
            .v32 => |v| blk: {
                var reversed = v;
                std.mem.reverse(u8, &reversed);
                break :blk .{ .v32 = reversed };
            },
            .v16 => |v| blk: {
                var reversed = v;
                std.mem.reverse(u8, &reversed);
                break :blk .{ .v16 = reversed };
            },
        };
    }

    /// Convert to big-endian from target endianness.
    pub fn toBigEndian(self: DataValue) DataValue {
        return if (@import("builtin").target.cpu.arch.endian() == .big)
            self
        else
            self.swapBytes();
    }

    /// Convert to little-endian from target endianness.
    pub fn toLittleEndian(self: DataValue) DataValue {
        return if (@import("builtin").target.cpu.arch.endian() == .little)
            self
        else
            self.swapBytes();
    }

    /// Write a DataValue to a slice in native-endian byte order.
    pub fn writeToSliceNativeEndian(self: DataValue, dst: []u8) void {
        switch (self) {
            .i8 => |i| @memcpy(dst[0..1], &std.mem.toBytes(i)),
            .i16 => |i| @memcpy(dst[0..2], &std.mem.toBytes(i)),
            .i32 => |i| @memcpy(dst[0..4], &std.mem.toBytes(i)),
            .i64 => |i| @memcpy(dst[0..8], &std.mem.toBytes(i)),
            .i128 => |i| @memcpy(dst[0..16], &std.mem.toBytes(i)),
            .f16 => |f| @memcpy(dst[0..2], &std.mem.toBytes(f)),
            .f32 => |f| @memcpy(dst[0..4], &std.mem.toBytes(f.bits())),
            .f64 => |f| @memcpy(dst[0..8], &std.mem.toBytes(f.bits())),
            .f128 => |f| @memcpy(dst[0..16], &std.mem.toBytes(f)),
            .v128 => |v| @memcpy(dst[0..16], &v),
            .v64 => |v| @memcpy(dst[0..8], &v),
            .v32 => |v| @memcpy(dst[0..4], &v),
            .v16 => |v| @memcpy(dst[0..2], &v),
        }
    }

    /// Write a DataValue to a slice in little-endian byte order.
    pub fn writeToSliceLittleEndian(self: DataValue, dst: []u8) void {
        self.toLittleEndian().writeToSliceNativeEndian(dst);
    }

    /// Write a DataValue to a slice in big-endian byte order.
    pub fn writeToSliceBigEndian(self: DataValue, dst: []u8) void {
        self.toBigEndian().writeToSliceNativeEndian(dst);
    }

    /// Get the size in bytes of this DataValue.
    pub fn sizeInBytes(self: DataValue) usize {
        return switch (self) {
            .i8 => 1,
            .i16, .f16, .v16 => 2,
            .i32, .f32, .v32 => 4,
            .i64, .f64, .v64 => 8,
            .i128, .f128, .v128 => 16,
        };
    }
};

const testing = std.testing;

test "DataValue fromInteger" {
    const dv = try DataValue.fromInteger(42, Type.I32);
    try testing.expectEqual(DataValue{ .i32 = 42 }, dv);
}

test "DataValue getType" {
    const dv = DataValue{ .i64 = 123 };
    try testing.expect(dv.getType().eql(Type.I64));
}

test "DataValue isVector" {
    try testing.expect((DataValue{ .v128 = undefined }).isVector());
    try testing.expect(!(DataValue{ .i32 = 0 }).isVector());
}

test "DataValue sizeInBytes" {
    try testing.expectEqual(@as(usize, 1), (DataValue{ .i8 = 0 }).sizeInBytes());
    try testing.expectEqual(@as(usize, 4), (DataValue{ .i32 = 0 }).sizeInBytes());
    try testing.expectEqual(@as(usize, 16), (DataValue{ .v128 = undefined }).sizeInBytes());
}
