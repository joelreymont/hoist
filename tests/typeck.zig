const std = @import("std");
const testing = std.testing;

const root = @import("root");
const types = root.types;
const Type = types.Type;

// ============================================================================
// Type Equality Tests
// ============================================================================

test "Type equality: identical types" {
    try testing.expect(Type.I32.eql(Type.I32));
    try testing.expect(Type.F64.eql(Type.F64));
    try testing.expect(Type.I8X16.eql(Type.I8X16));
}

test "Type equality: different types" {
    try testing.expect(!Type.I32.eql(Type.I64));
    try testing.expect(!Type.F32.eql(Type.F64));
    try testing.expect(!Type.I32.eql(Type.F32));
    try testing.expect(!Type.I32X4.eql(Type.I64));
}

test "Type equality: invalid type" {
    try testing.expect(Type.INVALID.eql(Type.INVALID));
    try testing.expect(!Type.INVALID.eql(Type.I32));
    try testing.expect(!Type.I32.eql(Type.INVALID));
}

// ============================================================================
// Type Compatibility Tests
// ============================================================================

test "Type compatibility: same-width integer and float" {
    // I32 and F32 both 32 bits, but not equal
    try testing.expect(!Type.I32.eql(Type.F32));
    try testing.expectEqual(Type.I32.bits(), Type.F32.bits());
    try testing.expectEqual(@as(u32, 32), Type.I32.bits());
    try testing.expectEqual(@as(u32, 32), Type.F32.bits());
}

test "Type compatibility: lane types match" {
    try testing.expect(Type.I32X4.laneType().eql(Type.I32));
    try testing.expect(Type.F64X2.laneType().eql(Type.F64));
    try testing.expect(Type.I8X16.laneType().eql(Type.I8));
}

test "Type compatibility: vector lane count" {
    try testing.expectEqual(@as(u32, 4), Type.I32X4.laneCount());
    try testing.expectEqual(@as(u32, 2), Type.F64X2.laneCount());
    try testing.expectEqual(@as(u32, 32), Type.I8X16.laneCount());
    try testing.expectEqual(@as(u32, 1), Type.I32.laneCount());
}

test "Type compatibility: total bits calculation" {
    // Scalar types
    try testing.expectEqual(@as(u32, 8), Type.I8.bits());
    try testing.expectEqual(@as(u32, 16), Type.I16.bits());
    try testing.expectEqual(@as(u32, 32), Type.I32.bits());
    try testing.expectEqual(@as(u32, 64), Type.I64.bits());
    try testing.expectEqual(@as(u32, 128), Type.I128.bits());

    // Vector types
    try testing.expectEqual(@as(u32, 128), Type.I32X4.bits()); // 32 * 4
    try testing.expectEqual(@as(u32, 128), Type.F32X4.bits()); // 32 * 4
    try testing.expectEqual(@as(u32, 128), Type.F64X2.bits()); // 64 * 2
    try testing.expectEqual(@as(u32, 256), Type.I8X16.bits()); // 8 * 32
}

test "Type compatibility: byte size calculation" {
    try testing.expectEqual(@as(u32, 1), Type.I8.bytes());
    try testing.expectEqual(@as(u32, 2), Type.I16.bytes());
    try testing.expectEqual(@as(u32, 4), Type.I32.bytes());
    try testing.expectEqual(@as(u32, 8), Type.I64.bytes());
    try testing.expectEqual(@as(u32, 16), Type.I128.bytes());
    try testing.expectEqual(@as(u32, 16), Type.I32X4.bytes());
}

// ============================================================================
// Type Promotion Tests
// ============================================================================

test "Type promotion: half-width conversion" {
    // Integer half-width
    try testing.expect(Type.I16.halfWidth().?.eql(Type.I8));
    try testing.expect(Type.I32.halfWidth().?.eql(Type.I16));
    try testing.expect(Type.I64.halfWidth().?.eql(Type.I32));
    try testing.expect(Type.I128.halfWidth().?.eql(Type.I64));

    // Float half-width
    try testing.expect(Type.F32.halfWidth().?.eql(Type.F16));
    try testing.expect(Type.F64.halfWidth().?.eql(Type.F32));
    try testing.expect(Type.F128.halfWidth().?.eql(Type.F64));

    // I8/F16 cannot be halved
    try testing.expect(Type.I8.halfWidth() == null);
    try testing.expect(Type.F16.halfWidth() == null);
}

test "Type promotion: double-width conversion" {
    // Integer double-width
    try testing.expect(Type.I8.doubleWidth().?.eql(Type.I16));
    try testing.expect(Type.I16.doubleWidth().?.eql(Type.I32));
    try testing.expect(Type.I32.doubleWidth().?.eql(Type.I64));
    try testing.expect(Type.I64.doubleWidth().?.eql(Type.I128));

    // Float double-width
    try testing.expect(Type.F16.doubleWidth().?.eql(Type.F32));
    try testing.expect(Type.F32.doubleWidth().?.eql(Type.F64));
    try testing.expect(Type.F64.doubleWidth().?.eql(Type.F128));

    // I128/F128 cannot be doubled
    try testing.expect(Type.I128.doubleWidth() == null);
    try testing.expect(Type.F128.doubleWidth() == null);
}

test "Type promotion: width conversion preserves lane structure" {
    // Vector half-width preserves lane count
    const i32x4_half = Type.I32X4.halfWidth().?;
    try testing.expectEqual(@as(u32, 4), i32x4_half.laneCount());
    try testing.expect(i32x4_half.laneType().eql(Type.I16));

    // Vector double-width preserves lane count
    const i32x4_double = Type.I32X4.doubleWidth().?;
    try testing.expectEqual(@as(u32, 4), i32x4_double.laneCount());
    try testing.expect(i32x4_double.laneType().eql(Type.I64));
}

test "Type promotion: asInt conversion" {
    // Scalars
    try testing.expect(Type.I32.asInt().eql(Type.I32));
    try testing.expect(Type.I64.asInt().eql(Type.I64));
    try testing.expect(Type.F32.asInt().eql(Type.I32));
    try testing.expect(Type.F64.asInt().eql(Type.I64));
    try testing.expect(Type.F16.asInt().eql(Type.I16));
    try testing.expect(Type.F128.asInt().eql(Type.I128));

    // Vectors
    const f32x4_int = Type.F32X4.asInt();
    try testing.expect(f32x4_int.laneType().eql(Type.I32));
    try testing.expectEqual(@as(u32, 4), f32x4_int.laneCount());

    const f64x2_int = Type.F64X2.asInt();
    try testing.expect(f64x2_int.laneType().eql(Type.I64));
    try testing.expectEqual(@as(u32, 2), f64x2_int.laneCount());
}

test "Type promotion: asTruthy conversion" {
    // Scalars always become I8
    try testing.expect(Type.I32.asTruthy().eql(Type.I8));
    try testing.expect(Type.I64.asTruthy().eql(Type.I8));
    try testing.expect(Type.F32.asTruthy().eql(Type.I8));
    try testing.expect(Type.F64.asTruthy().eql(Type.I8));

    // Vectors preserve lane count, use integer type
    const i32x4_truthy = Type.I32X4.asTruthy();
    try testing.expect(i32x4_truthy.laneType().eql(Type.I32));
    try testing.expectEqual(@as(u32, 4), i32x4_truthy.laneCount());

    const f32x4_truthy = Type.F32X4.asTruthy();
    try testing.expect(f32x4_truthy.laneType().eql(Type.I32));
    try testing.expectEqual(@as(u32, 4), f32x4_truthy.laneCount());
}

// ============================================================================
// Type Validation Tests
// ============================================================================

test "Type validation: invalid type properties" {
    const invalid = Type.INVALID;

    try testing.expect(invalid.isInvalid());
    try testing.expect(!invalid.isInt());
    try testing.expect(!invalid.isFloat());
    try testing.expect(!invalid.isVector());
    try testing.expect(!invalid.isLane());
    try testing.expect(invalid.isSpecial());
}

test "Type validation: integer type classification" {
    // Integer types
    try testing.expect(Type.I8.isInt());
    try testing.expect(Type.I16.isInt());
    try testing.expect(Type.I32.isInt());
    try testing.expect(Type.I64.isInt());
    try testing.expect(Type.I128.isInt());

    // Not integers
    try testing.expect(!Type.F32.isInt());
    try testing.expect(!Type.F64.isInt());
    try testing.expect(!Type.INVALID.isInt());
}

test "Type validation: float type classification" {
    // Float types
    try testing.expect(Type.F16.isFloat());
    try testing.expect(Type.F32.isFloat());
    try testing.expect(Type.F64.isFloat());
    try testing.expect(Type.F128.isFloat());

    // Not floats
    try testing.expect(!Type.I32.isFloat());
    try testing.expect(!Type.I64.isFloat());
    try testing.expect(!Type.INVALID.isFloat());
}

test "Type validation: vector type classification" {
    // Vector types
    try testing.expect(Type.I8X16.isVector());
    try testing.expect(Type.I32X4.isVector());
    try testing.expect(Type.F32X4.isVector());
    try testing.expect(Type.F64X2.isVector());

    // Not vectors
    try testing.expect(!Type.I32.isVector());
    try testing.expect(!Type.F64.isVector());
    try testing.expect(!Type.INVALID.isVector());
}

test "Type validation: lane type classification" {
    // Lane types (scalars in lane range)
    try testing.expect(Type.I8.isLane());
    try testing.expect(Type.I16.isLane());
    try testing.expect(Type.I32.isLane());
    try testing.expect(Type.I64.isLane());
    try testing.expect(Type.F32.isLane());
    try testing.expect(Type.F64.isLane());

    // Not lane types (vectors)
    try testing.expect(!Type.I32X4.isLane());
    try testing.expect(!Type.F64X2.isLane());
}

test "Type validation: lane bits calculation" {
    try testing.expectEqual(@as(u32, 8), Type.I8.laneBits());
    try testing.expectEqual(@as(u32, 16), Type.I16.laneBits());
    try testing.expectEqual(@as(u32, 32), Type.I32.laneBits());
    try testing.expectEqual(@as(u32, 64), Type.I64.laneBits());
    try testing.expectEqual(@as(u32, 128), Type.I128.laneBits());

    try testing.expectEqual(@as(u32, 16), Type.F16.laneBits());
    try testing.expectEqual(@as(u32, 32), Type.F32.laneBits());
    try testing.expectEqual(@as(u32, 64), Type.F64.laneBits());
    try testing.expectEqual(@as(u32, 128), Type.F128.laneBits());

    // Vectors report lane bits, not total bits
    try testing.expectEqual(@as(u32, 32), Type.I32X4.laneBits());
    try testing.expectEqual(@as(u32, 64), Type.F64X2.laneBits());
}

test "Type validation: log2 calculations" {
    // Lane count log2
    try testing.expectEqual(@as(u32, 0), Type.I32.log2LaneCount()); // 1 lane
    try testing.expectEqual(@as(u32, 1), Type.F64X2.log2LaneCount()); // 2 lanes
    try testing.expectEqual(@as(u32, 2), Type.I32X4.log2LaneCount()); // 4 lanes
    try testing.expectEqual(@as(u32, 5), Type.I8X16.log2LaneCount()); // 32 lanes

    // Lane bits log2
    try testing.expectEqual(@as(u32, 3), Type.I8.log2LaneBits()); // 8 = 2^3
    try testing.expectEqual(@as(u32, 4), Type.I16.log2LaneBits()); // 16 = 2^4
    try testing.expectEqual(@as(u32, 5), Type.I32.log2LaneBits()); // 32 = 2^5
    try testing.expectEqual(@as(u32, 6), Type.I64.log2LaneBits()); // 64 = 2^6
}

// ============================================================================
// Type Constructor Tests
// ============================================================================

test "Type constructor: int by width" {
    try testing.expect(Type.int(8).?.eql(Type.I8));
    try testing.expect(Type.int(16).?.eql(Type.I16));
    try testing.expect(Type.int(32).?.eql(Type.I32));
    try testing.expect(Type.int(64).?.eql(Type.I64));
    try testing.expect(Type.int(128).?.eql(Type.I128));

    // Invalid widths
    try testing.expect(Type.int(7) == null);
    try testing.expect(Type.int(33) == null);
    try testing.expect(Type.int(0) == null);
}

test "Type constructor: int by byte size" {
    try testing.expect(Type.intWithByteSize(1).?.eql(Type.I8));
    try testing.expect(Type.intWithByteSize(2).?.eql(Type.I16));
    try testing.expect(Type.intWithByteSize(4).?.eql(Type.I32));
    try testing.expect(Type.intWithByteSize(8).?.eql(Type.I64));
    try testing.expect(Type.intWithByteSize(16).?.eql(Type.I128));

    // Invalid sizes
    try testing.expect(Type.intWithByteSize(3) == null);
    try testing.expect(Type.intWithByteSize(0) == null);
}

// ============================================================================
// Type Format Tests
// ============================================================================

test "Type format: scalar integers" {
    var buf: [32]u8 = undefined;

    const s1 = try std.fmt.bufPrint(&buf, "{f}", .{Type.I8});
    try testing.expectEqualStrings("i8", s1);

    const s2 = try std.fmt.bufPrint(&buf, "{f}", .{Type.I16});
    try testing.expectEqualStrings("i16", s2);

    const s3 = try std.fmt.bufPrint(&buf, "{f}", .{Type.I32});
    try testing.expectEqualStrings("i32", s3);

    const s4 = try std.fmt.bufPrint(&buf, "{f}", .{Type.I64});
    try testing.expectEqualStrings("i64", s4);

    const s5 = try std.fmt.bufPrint(&buf, "{f}", .{Type.I128});
    try testing.expectEqualStrings("i128", s5);
}

test "Type format: scalar floats" {
    var buf: [32]u8 = undefined;

    const s1 = try std.fmt.bufPrint(&buf, "{f}", .{Type.F16});
    try testing.expectEqualStrings("f16", s1);

    const s2 = try std.fmt.bufPrint(&buf, "{f}", .{Type.F32});
    try testing.expectEqualStrings("f32", s2);

    const s3 = try std.fmt.bufPrint(&buf, "{f}", .{Type.F64});
    try testing.expectEqualStrings("f64", s3);

    const s4 = try std.fmt.bufPrint(&buf, "{f}", .{Type.F128});
    try testing.expectEqualStrings("f128", s4);
}

test "Type format: vectors" {
    var buf: [32]u8 = undefined;

    const s1 = try std.fmt.bufPrint(&buf, "{f}", .{Type.I8X16});
    try testing.expectEqualStrings("i8x32", s1);

    const s2 = try std.fmt.bufPrint(&buf, "{f}", .{Type.I32X4});
    try testing.expectEqualStrings("i32x4", s2);

    const s3 = try std.fmt.bufPrint(&buf, "{f}", .{Type.F32X4});
    try testing.expectEqualStrings("f32x4", s3);

    const s4 = try std.fmt.bufPrint(&buf, "{f}", .{Type.F64X2});
    try testing.expectEqualStrings("f64x2", s4);
}

test "Type format: invalid type" {
    var buf: [32]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf, "{f}", .{Type.INVALID});
    try testing.expectEqualStrings("invalid", s);
}

// ============================================================================
// IR Operation Type Validation Tests
// ============================================================================

test "IR type validation: binary operation type matching" {
    // Same types should be compatible for binary ops
    try testing.expect(Type.I32.eql(Type.I32));
    try testing.expect(Type.I64.eql(Type.I64));
    try testing.expect(Type.F32.eql(Type.F32));

    // Different types should not match
    try testing.expect(!Type.I32.eql(Type.I64));
    try testing.expect(!Type.F32.eql(Type.F64));
    try testing.expect(!Type.I32.eql(Type.F32));
}

test "IR type validation: comparison result types" {
    // Scalar comparisons produce I8
    try testing.expect(Type.I32.asTruthy().eql(Type.I8));
    try testing.expect(Type.I64.asTruthy().eql(Type.I8));
    try testing.expect(Type.F32.asTruthy().eql(Type.I8));
    try testing.expect(Type.F64.asTruthy().eql(Type.I8));

    // Vector comparisons preserve lane structure
    const i32x4_cmp = Type.I32X4.asTruthy();
    try testing.expectEqual(@as(u32, 4), i32x4_cmp.laneCount());
    try testing.expect(i32x4_cmp.laneType().eql(Type.I32));
}

test "IR type validation: conversion operation types" {
    // Int to float (same width)
    try testing.expectEqual(Type.I32.bits(), Type.F32.bits());
    try testing.expectEqual(Type.I64.bits(), Type.F64.bits());

    // Extending conversions
    const i32_extend = Type.I32.doubleWidth().?;
    try testing.expect(i32_extend.eql(Type.I64));
    try testing.expectEqual(@as(u32, 64), i32_extend.bits());

    // Truncating conversions
    const i64_trunc = Type.I64.halfWidth().?;
    try testing.expect(i64_trunc.eql(Type.I32));
    try testing.expectEqual(@as(u32, 32), i64_trunc.bits());
}

test "IR type validation: bitcast type compatibility" {
    // Same-width types can bitcast
    try testing.expectEqual(Type.I32.bits(), Type.F32.bits());
    try testing.expectEqual(Type.I64.bits(), Type.F64.bits());
    try testing.expectEqual(Type.I32X4.bits(), Type.F32X4.bits());

    // Different-width types cannot bitcast
    try testing.expect(Type.I32.bits() != Type.I64.bits());
    try testing.expect(Type.F32.bits() != Type.F64.bits());
}

test "IR type validation: load and store alignment" {
    // Type byte size determines natural alignment
    try testing.expectEqual(@as(u32, 1), Type.I8.bytes());
    try testing.expectEqual(@as(u32, 2), Type.I16.bytes());
    try testing.expectEqual(@as(u32, 4), Type.I32.bytes());
    try testing.expectEqual(@as(u32, 8), Type.I64.bytes());

    // Vectors have larger alignment requirements
    try testing.expectEqual(@as(u32, 16), Type.I32X4.bytes());
    try testing.expectEqual(@as(u32, 16), Type.F64X2.bytes());
}

test "IR type validation: select operation types" {
    // Select requires condition type (I8 for scalars)
    const cond_type = Type.I32.asTruthy();
    try testing.expect(cond_type.eql(Type.I8));

    // Vector selects need vector condition
    const vec_cond = Type.I32X4.asTruthy();
    try testing.expect(vec_cond.laneType().eql(Type.I32));
    try testing.expectEqual(@as(u32, 4), vec_cond.laneCount());
}

// ============================================================================
// Edge Case Tests
// ============================================================================

test "Type edge cases: boundary widths" {
    // Smallest and largest types
    try testing.expectEqual(@as(u32, 8), Type.I8.bits());
    try testing.expectEqual(@as(u32, 128), Type.I128.bits());
    try testing.expectEqual(@as(u32, 128), Type.F128.bits());

    // Cannot go beyond boundaries
    try testing.expect(Type.I8.halfWidth() == null);
    try testing.expect(Type.I128.doubleWidth() == null);
    try testing.expect(Type.F16.halfWidth() == null);
    try testing.expect(Type.F128.doubleWidth() == null);
}

test "Type edge cases: vector lane limits" {
    // Various lane counts (powers of 2)
    try testing.expectEqual(@as(u32, 1), Type.I32.laneCount());
    try testing.expectEqual(@as(u32, 2), Type.F64X2.laneCount());
    try testing.expectEqual(@as(u32, 4), Type.I32X4.laneCount());
    try testing.expectEqual(@as(u32, 32), Type.I8X16.laneCount());
}

test "Type edge cases: mixed width operations" {
    // Verify different widths don't accidentally match
    const types_list = [_]Type{
        Type.I8,  Type.I16, Type.I32, Type.I64,  Type.I128,
        Type.F16, Type.F32, Type.F64, Type.F128,
    };

    for (types_list, 0..) |t1, i| {
        for (types_list, 0..) |t2, j| {
            if (i == j) {
                try testing.expect(t1.eql(t2));
            } else {
                try testing.expect(!t1.eql(t2));
            }
        }
    }
}

test "Type edge cases: type roundtrip conversions" {
    // Double then half should return to original (where possible)
    const i16_to_i32 = Type.I16.doubleWidth().?;
    const i32_to_i16 = i16_to_i32.halfWidth().?;
    try testing.expect(i32_to_i16.eql(Type.I16));

    const f32_to_f64 = Type.F32.doubleWidth().?;
    const f64_to_f32 = f32_to_f64.halfWidth().?;
    try testing.expect(f64_to_f32.eql(Type.F32));
}
