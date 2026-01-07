//! Unit tests for IR type system.

const std = @import("std");
const testing = std.testing;
const types = @import("types.zig");

const Type = types.Type;

// Basic type properties

test "Type.INVALID is invalid" {
    try testing.expect(Type.INVALID.isInvalid());
}

test "Type scalar integers are not invalid" {
    try testing.expect(!Type.I8.isInvalid());
    try testing.expect(!Type.I16.isInvalid());
    try testing.expect(!Type.I32.isInvalid());
    try testing.expect(!Type.I64.isInvalid());
    try testing.expect(!Type.I128.isInvalid());
}

test "Type scalar floats are not invalid" {
    try testing.expect(!Type.F16.isInvalid());
    try testing.expect(!Type.F32.isInvalid());
    try testing.expect(!Type.F64.isInvalid());
    try testing.expect(!Type.F128.isInvalid());
}

test "Type.isInt: scalar integers" {
    try testing.expect(Type.I8.isInt());
    try testing.expect(Type.I16.isInt());
    try testing.expect(Type.I32.isInt());
    try testing.expect(Type.I64.isInt());
    try testing.expect(Type.I128.isInt());
}

test "Type.isInt: floats are not integers" {
    try testing.expect(!Type.F16.isInt());
    try testing.expect(!Type.F32.isInt());
    try testing.expect(!Type.F64.isInt());
    try testing.expect(!Type.F128.isInt());
}

test "Type.isFloat: scalar floats" {
    try testing.expect(Type.F16.isFloat());
    try testing.expect(Type.F32.isFloat());
    try testing.expect(Type.F64.isFloat());
    try testing.expect(Type.F128.isFloat());
}

test "Type.isFloat: integers are not floats" {
    try testing.expect(!Type.I8.isFloat());
    try testing.expect(!Type.I16.isFloat());
    try testing.expect(!Type.I32.isFloat());
    try testing.expect(!Type.I64.isFloat());
    try testing.expect(!Type.I128.isFloat());
}

test "Type.isLane: scalar types are lanes" {
    try testing.expect(Type.I8.isLane());
    try testing.expect(Type.I16.isLane());
    try testing.expect(Type.I32.isLane());
    try testing.expect(Type.I64.isLane());
    try testing.expect(Type.I128.isLane());
    try testing.expect(Type.F16.isLane());
    try testing.expect(Type.F32.isLane());
    try testing.expect(Type.F64.isLane());
    try testing.expect(Type.F128.isLane());
}

test "Type.isVector: vectors are vectors" {
    try testing.expect(Type.I8X16.isVector());
    try testing.expect(Type.I16X8.isVector());
    try testing.expect(Type.I32X4.isVector());
    try testing.expect(Type.I64X2.isVector());
    try testing.expect(Type.F32X4.isVector());
    try testing.expect(Type.F64X2.isVector());
}

test "Type.isVector: scalars are not vectors" {
    try testing.expect(!Type.I8.isVector());
    try testing.expect(!Type.I16.isVector());
    try testing.expect(!Type.I32.isVector());
    try testing.expect(!Type.I64.isVector());
    try testing.expect(!Type.F32.isVector());
    try testing.expect(!Type.F64.isVector());
}

test "Type.laneType: scalars return self" {
    try testing.expect(Type.I8.laneType().eql(Type.I8));
    try testing.expect(Type.I16.laneType().eql(Type.I16));
    try testing.expect(Type.I32.laneType().eql(Type.I32));
    try testing.expect(Type.I64.laneType().eql(Type.I64));
    try testing.expect(Type.F32.laneType().eql(Type.F32));
    try testing.expect(Type.F64.laneType().eql(Type.F64));
}

test "Type.laneType: vectors return lane type" {
    // I32X4 should have I32 lanes
    try testing.expect(Type.I32X4.laneType().eql(Type.I32));
    // I64X2 should have I64 lanes
    try testing.expect(Type.I64X2.laneType().eql(Type.I64));
    // F32X4 should have F32 lanes
    try testing.expect(Type.F32X4.laneType().eql(Type.F32));
    // F64X2 should have F64 lanes
    try testing.expect(Type.F64X2.laneType().eql(Type.F64));
}

test "Type.laneCount: scalars have 1 lane" {
    try testing.expectEqual(@as(u32, 1), Type.I8.laneCount());
    try testing.expectEqual(@as(u32, 1), Type.I16.laneCount());
    try testing.expectEqual(@as(u32, 1), Type.I32.laneCount());
    try testing.expectEqual(@as(u32, 1), Type.I64.laneCount());
    try testing.expectEqual(@as(u32, 1), Type.F32.laneCount());
    try testing.expectEqual(@as(u32, 1), Type.F64.laneCount());
}

test "Type.laneCount: vectors have correct count" {
    try testing.expectEqual(@as(u32, 16), Type.I8X16.laneCount());
    try testing.expectEqual(@as(u32, 8), Type.I16X8.laneCount());
    try testing.expectEqual(@as(u32, 4), Type.I32X4.laneCount());
    try testing.expectEqual(@as(u32, 2), Type.I64X2.laneCount());
    try testing.expectEqual(@as(u32, 4), Type.F32X4.laneCount());
    try testing.expectEqual(@as(u32, 2), Type.F64X2.laneCount());
}

test "Type.log2LaneCount: scalars have log2(1) = 0" {
    try testing.expectEqual(@as(u32, 0), Type.I32.log2LaneCount());
    try testing.expectEqual(@as(u32, 0), Type.I64.log2LaneCount());
    try testing.expectEqual(@as(u32, 0), Type.F32.log2LaneCount());
    try testing.expectEqual(@as(u32, 0), Type.F64.log2LaneCount());
}

test "Type.log2LaneCount: vectors have correct log2" {
    try testing.expectEqual(@as(u32, 4), Type.I8X16.log2LaneCount()); // log2(16) = 4
    try testing.expectEqual(@as(u32, 3), Type.I16X8.log2LaneCount()); // log2(8) = 3
    try testing.expectEqual(@as(u32, 2), Type.I32X4.log2LaneCount()); // log2(4) = 2
    try testing.expectEqual(@as(u32, 1), Type.I64X2.log2LaneCount()); // log2(2) = 1
    try testing.expectEqual(@as(u32, 2), Type.F32X4.log2LaneCount()); // log2(4) = 2
    try testing.expectEqual(@as(u32, 1), Type.F64X2.log2LaneCount()); // log2(2) = 1
}

test "Type.eql: equality is reflexive" {
    try testing.expect(Type.I32.eql(Type.I32));
    try testing.expect(Type.I64.eql(Type.I64));
    try testing.expect(Type.F32.eql(Type.F32));
    try testing.expect(Type.I32X4.eql(Type.I32X4));
}

test "Type.eql: different types not equal" {
    try testing.expect(!Type.I32.eql(Type.I64));
    try testing.expect(!Type.F32.eql(Type.F64));
    try testing.expect(!Type.I32.eql(Type.F32));
    try testing.expect(!Type.I32X4.eql(Type.I64X2));
}

test "Type.eql: scalars not equal to vectors" {
    try testing.expect(!Type.I32.eql(Type.I32X4));
    try testing.expect(!Type.F32.eql(Type.F32X4));
}

test "Type integer sizes" {
    // Verify we have all standard integer sizes
    try testing.expect(!Type.I8.isInvalid());
    try testing.expect(!Type.I16.isInvalid());
    try testing.expect(!Type.I32.isInvalid());
    try testing.expect(!Type.I64.isInvalid());
    try testing.expect(!Type.I128.isInvalid());
}

test "Type float sizes" {
    // Verify we have all standard float sizes
    try testing.expect(!Type.F16.isInvalid());
    try testing.expect(!Type.F32.isInvalid());
    try testing.expect(!Type.F64.isInvalid());
    try testing.expect(!Type.F128.isInvalid());
}

test "Type common vector types exist" {
    // Verify common SIMD vector types are defined
    try testing.expect(!Type.I8X16.isInvalid());
    try testing.expect(!Type.I16X8.isInvalid());
    try testing.expect(!Type.I32X4.isInvalid());
    try testing.expect(!Type.I64X2.isInvalid());
    try testing.expect(!Type.F32X4.isInvalid());
    try testing.expect(!Type.F64X2.isInvalid());
}

test "Type vector properties are consistent" {
    // Vector type should be a vector, not a lane
    try testing.expect(Type.I32X4.isVector());
    try testing.expect(!Type.I32X4.isLane());

    // Scalar type should be a lane, not a vector
    try testing.expect(Type.I32.isLane());
    try testing.expect(!Type.I32.isVector());
}

test "Type lane count and log2 are consistent" {
    // For vectors: laneCount == 2^log2LaneCount
    const vectors = [_]Type{ Type.I8X16, Type.I16X8, Type.I32X4, Type.I64X2, Type.F32X4, Type.F64X2 };
    for (vectors) |vec| {
        const count = vec.laneCount();
        const log2_count = vec.log2LaneCount();
        try testing.expectEqual(count, @as(u32, 1) << @intCast(log2_count));
    }
}

test "Type integer and float are mutually exclusive" {
    // No type should be both int and float
    const all_types = [_]Type{
        Type.I8,    Type.I16,   Type.I32,   Type.I64,   Type.I128,
        Type.F16,   Type.F32,   Type.F64,   Type.F128,  Type.I8X16,
        Type.I16X8, Type.I32X4, Type.I64X2, Type.F32X4, Type.F64X2,
    };
    for (all_types) |t| {
        try testing.expect(!(t.isInt() and t.isFloat()));
    }
}
