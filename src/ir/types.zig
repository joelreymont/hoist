//! Cranelift IR type system.
//!
//! SSA value types for integers, floats, and SIMD vectors.
//! Encoded as u16 with the following ranges:
//! - 0x00: INVALID
//! - 0x01-0x6f: Special types
//! - 0x70-0x7d: Lane types (scalar int/float)
//! - 0x7e-0x7f: Reference types
//! - 0x80-0xff: Vector types (2-256 lanes, power of 2)
//! - 0x100-0x17f: Dynamic vector types

const std = @import("std");

// Type encoding constants
const LANE_BASE: u16 = 0x70;
const REFERENCE_BASE: u16 = 0x7E;
const VECTOR_BASE: u16 = 0x80;
const DYNAMIC_VECTOR_BASE: u16 = 0x100;

/// SSA value type.
pub const Type = packed struct {
    raw: u16,

    pub const INVALID = Type{ .raw = 0 };

    // Scalar integers (from generated Cranelift types)
    pub const I8 = Type{ .raw = 0x74 };
    pub const I16 = Type{ .raw = 0x75 };
    pub const I32 = Type{ .raw = 0x76 };
    pub const I64 = Type{ .raw = 0x77 };
    pub const I128 = Type{ .raw = 0x78 };

    // Scalar floats
    pub const F16 = Type{ .raw = 0x79 };
    pub const F32 = Type{ .raw = 0x7a };
    pub const F64 = Type{ .raw = 0x7b };
    pub const F128 = Type{ .raw = 0x7c };

    // Common vector types
    pub const I8X16 = Type{ .raw = 0xb4 };
    pub const I16X8 = Type{ .raw = 0xa5 };
    pub const I32X4 = Type{ .raw = 0x96 };
    pub const I64X2 = Type{ .raw = 0x87 };
    pub const F32X4 = Type{ .raw = 0x9a };
    pub const F64X2 = Type{ .raw = 0x8b };

    pub fn eql(self: Type, other: Type) bool {
        return self.raw == other.raw;
    }

    pub fn isInvalid(self: Type) bool {
        return self.raw == 0;
    }

    pub fn isSpecial(self: Type) bool {
        return self.raw < LANE_BASE;
    }

    pub fn isLane(self: Type) bool {
        return self.raw >= LANE_BASE and self.raw < VECTOR_BASE;
    }

    pub fn isVector(self: Type) bool {
        return self.raw >= VECTOR_BASE and !self.isDynamicVector();
    }

    pub fn isDynamicVector(self: Type) bool {
        return self.raw >= DYNAMIC_VECTOR_BASE;
    }

    pub fn isInt(self: Type) bool {
        return self.eql(I8) or self.eql(I16) or self.eql(I32) or
            self.eql(I64) or self.eql(I128);
    }

    pub fn isFloat(self: Type) bool {
        return self.eql(F16) or self.eql(F32) or self.eql(F64) or self.eql(F128);
    }

    /// Get lane type of vector (or self for scalars).
    pub fn laneType(self: Type) Type {
        if (self.raw < VECTOR_BASE) {
            return self;
        } else {
            return .{ .raw = LANE_BASE | (self.raw & 0x0f) };
        }
    }

    /// Log2 of lane count (0-8 for 1-256 lanes).
    pub fn log2LaneCount(self: Type) u32 {
        if (self.isDynamicVector()) {
            return 0;
        }
        const offset = if (self.raw >= LANE_BASE) self.raw - LANE_BASE else 0;
        return @intCast(offset >> 4);
    }

    /// Number of lanes (1 for scalars, 2-256 for vectors).
    pub fn laneCount(self: Type) u32 {
        if (self.isDynamicVector()) {
            return 0;
        } else {
            return @as(u32, 1) << @intCast(self.log2LaneCount());
        }
    }

    /// Number of bits in a single lane.
    pub fn laneBits(self: Type) u32 {
        return switch (self.laneType().raw) {
            I8.raw => 8,
            I16.raw, F16.raw => 16,
            I32.raw, F32.raw => 32,
            I64.raw, F64.raw => 64,
            I128.raw, F128.raw => 128,
            else => 0,
        };
    }

    /// Log2 of bits in a lane.
    pub fn log2LaneBits(self: Type) u32 {
        return switch (self.laneType().raw) {
            I8.raw => 3,
            I16.raw, F16.raw => 4,
            I32.raw, F32.raw => 5,
            I64.raw, F64.raw => 6,
            I128.raw, F128.raw => 7,
            else => 0,
        };
    }

    /// Total bits for this type.
    pub fn bits(self: Type) u32 {
        if (self.isDynamicVector()) {
            return 0;
        } else {
            return self.laneBits() * self.laneCount();
        }
    }

    /// Bytes required to store this type.
    pub fn bytes(self: Type) u32 {
        return (self.bits() + 7) / 8;
    }

    /// Get integer type with given bit width.
    pub fn int(width: u16) ?Type {
        return switch (width) {
            8 => I8,
            16 => I16,
            32 => I32,
            64 => I64,
            128 => I128,
            else => null,
        };
    }

    /// Get integer type with given byte size.
    pub fn intWithByteSize(size: u16) ?Type {
        const bits_opt = std.math.mul(u16, size, 8) catch null;
        return if (bits_opt) |b| Type.int(b) else null;
    }

    /// Create a vector type with the given lane type and lane count.
    pub fn vector(lane_type: Type, lane_count: u32) ?Type {
        if (!lane_type.isLane()) return null;
        if (lane_count < 2 or lane_count > 256) return null;
        if (!std.math.isPowerOfTwo(lane_count)) return null;
        const log2_lanes = std.math.log2_int(u32, lane_count);
        const lane_bits: u16 = lane_type.raw & 0x0f;
        return .{ .raw = LANE_BASE + (@as(u16, log2_lanes) << 4) + lane_bits };
    }

    /// Type with same lane count but different lane type.
    fn replaceLanes(self: Type, lane: Type) Type {
        std.debug.assert(lane.isLane() and !self.isSpecial());
        return .{ .raw = (lane.raw & 0x0f) | (self.raw & 0xf0) };
    }

    /// Convert to integer type (same width, int lanes).
    pub fn asInt(self: Type) Type {
        return self.replaceLanes(switch (self.laneType().raw) {
            I8.raw => I8,
            I16.raw, F16.raw => I16,
            I32.raw, F32.raw => I32,
            I64.raw, F64.raw => I64,
            I128.raw, F128.raw => I128,
            else => unreachable,
        });
    }

    /// Comparison result type (i8 for scalars, iN lanes for vectors).
    pub fn asTruthy(self: Type) Type {
        if (!self.isVector()) {
            return I8;
        } else {
            return self.asTruthyPedantic();
        }
    }

    fn asTruthyPedantic(self: Type) Type {
        return self.replaceLanes(switch (self.laneType().raw) {
            I8.raw => I8,
            I16.raw, F16.raw => I16,
            I32.raw, F32.raw => I32,
            I64.raw, F64.raw => I64,
            I128.raw, F128.raw => I128,
            else => I8,
        });
    }

    /// Half-width lanes (I32 -> I16, F64 -> F32, etc.).
    pub fn halfWidth(self: Type) ?Type {
        const half_lane = switch (self.laneType().raw) {
            I16.raw => I8,
            I32.raw => I16,
            I64.raw => I32,
            I128.raw => I64,
            F32.raw => F16,
            F64.raw => F32,
            F128.raw => F64,
            else => return null,
        };
        return self.replaceLanes(half_lane);
    }

    /// Double-width lanes (I32 -> I64, F32 -> F64, etc.).
    pub fn doubleWidth(self: Type) ?Type {
        const double_lane = switch (self.laneType().raw) {
            I8.raw => I16,
            I16.raw => I32,
            I32.raw => I64,
            I64.raw => I128,
            F16.raw => F32,
            F32.raw => F64,
            F64.raw => F128,
            else => return null,
        };
        return self.replaceLanes(double_lane);
    }

    /// Format as string (i32, f64, i32x4, etc.).
    pub fn format(self: Type, writer: anytype) !void {
        if (self.isInvalid()) {
            try writer.writeAll("invalid");
            return;
        }

        const lane = self.laneType();
        const lane_str = switch (lane.raw) {
            I8.raw => "i8",
            I16.raw => "i16",
            I32.raw => "i32",
            I64.raw => "i64",
            I128.raw => "i128",
            F16.raw => "f16",
            F32.raw => "f32",
            F64.raw => "f64",
            F128.raw => "f128",
            else => "?",
        };

        if (self.isVector()) {
            try writer.print("{s}x{d}", .{ lane_str, self.laneCount() });
        } else {
            try writer.writeAll(lane_str);
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Type basic" {
    try std.testing.expect(!Type.INVALID.isInt());
    try std.testing.expect(Type.INVALID.isInvalid());
    try std.testing.expect(Type.I32.isInt());
    try std.testing.expect(!Type.I32.isFloat());
    try std.testing.expect(Type.F64.isFloat());
    try std.testing.expect(!Type.F64.isInt());
}

test "Type sizes" {
    try std.testing.expectEqual(@as(u32, 32), Type.I32.bits());
    try std.testing.expectEqual(@as(u32, 4), Type.I32.bytes());
    try std.testing.expectEqual(@as(u32, 128), Type.F128.bits());
    try std.testing.expectEqual(@as(u32, 16), Type.F128.bytes());
}

test "Type vector" {
    try std.testing.expect(Type.I32X4.isVector());
    try std.testing.expect(!Type.I32.isVector());
    try std.testing.expectEqual(@as(u32, 4), Type.I32X4.laneCount());
    try std.testing.expectEqual(@as(u32, 1), Type.I32.laneCount());
    try std.testing.expect(Type.I32X4.laneType().eql(Type.I32));
    try std.testing.expectEqual(@as(u32, 128), Type.I32X4.bits());
}

test "Type lane operations" {
    try std.testing.expectEqual(@as(u32, 32), Type.I32.laneBits());
    try std.testing.expectEqual(@as(u32, 5), Type.I32.log2LaneBits());
    try std.testing.expectEqual(@as(u32, 16), Type.F16.laneBits());
}

test "Type width conversion" {
    try std.testing.expect(Type.I32.halfWidth().?.eql(Type.I16));
    try std.testing.expect(Type.I16.doubleWidth().?.eql(Type.I32));
    try std.testing.expect(Type.F32.halfWidth().?.eql(Type.F16));
    try std.testing.expect(Type.F64.doubleWidth().?.eql(Type.F128));
    try std.testing.expect(Type.F128.doubleWidth() == null);
}

test "Type asInt" {
    try std.testing.expect(Type.F32.asInt().eql(Type.I32));
    try std.testing.expect(Type.F64.asInt().eql(Type.I64));
    try std.testing.expect(Type.I32.asInt().eql(Type.I32));
}

test "Type asTruthy" {
    try std.testing.expect(Type.I32.asTruthy().eql(Type.I8));
    try std.testing.expect(Type.F64.asTruthy().eql(Type.I8));
    try std.testing.expect(Type.I32X4.asTruthy().eql(Type.I32X4));
}

test "Type format" {
    var buf: [32]u8 = undefined;

    const s1 = try std.fmt.bufPrint(&buf, "{f}", .{Type.I32});
    try std.testing.expectEqualStrings("i32", s1);

    const s2 = try std.fmt.bufPrint(&buf, "{f}", .{Type.F64});
    try std.testing.expectEqualStrings("f64", s2);

    const s3 = try std.fmt.bufPrint(&buf, "{f}", .{Type.I32X4});
    try std.testing.expectEqualStrings("i32x4", s3);

    const s4 = try std.fmt.bufPrint(&buf, "{f}", .{Type.INVALID});
    try std.testing.expectEqualStrings("invalid", s4);
}

test "Type int constructors" {
    try std.testing.expect(Type.int(32).?.eql(Type.I32));
    try std.testing.expect(Type.int(64).?.eql(Type.I64));
    try std.testing.expect(Type.int(7) == null);

    try std.testing.expect(Type.intWithByteSize(4).?.eql(Type.I32));
    try std.testing.expect(Type.intWithByteSize(8).?.eql(Type.I64));
}
