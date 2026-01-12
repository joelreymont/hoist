//! Tests for ValueRange interval arithmetic and RangeAnalysis propagation.

const std = @import("std");
const testing = std.testing;

const hoist = @import("hoist");
const ValueRange = hoist.ir_ns.value_range.ValueRange;

// ============================================================================
// ValueRange Basic Operations
// ============================================================================

test "ValueRange: empty range" {
    const r = ValueRange.empty(32, true);
    try testing.expect(r.isEmpty());
    try testing.expect(!r.contains(0));
    try testing.expect(!r.isConstant());
}

test "ValueRange: full signed 32-bit range" {
    const r = ValueRange.full(32, true);
    try testing.expect(!r.isEmpty());
    try testing.expect(r.contains(0));
    try testing.expect(r.contains(-1));
    try testing.expect(r.contains(-2147483648)); // i32 min
    try testing.expect(r.contains(2147483647)); // i32 max
    try testing.expectEqual(@as(i64, -2147483648), r.min);
    try testing.expectEqual(@as(i64, 2147483647), r.max);
}

test "ValueRange: full unsigned 32-bit range" {
    const r = ValueRange.full(32, false);
    try testing.expect(r.contains(0));
    try testing.expect(r.contains(4294967295)); // u32 max
    try testing.expectEqual(@as(i64, 0), r.min);
    try testing.expectEqual(@as(i64, 4294967295), r.max);
}

test "ValueRange: constant" {
    const r = ValueRange.constant(42, 32, true);
    try testing.expect(r.isConstant());
    try testing.expectEqual(@as(?i64, 42), r.getConstant());
    try testing.expect(r.contains(42));
    try testing.expect(!r.contains(41));
    try testing.expect(!r.contains(43));
}

test "ValueRange: 8-bit ranges" {
    const signed = ValueRange.full(8, true);
    try testing.expectEqual(@as(i64, -128), signed.min);
    try testing.expectEqual(@as(i64, 127), signed.max);

    const unsigned = ValueRange.full(8, false);
    try testing.expectEqual(@as(i64, 0), unsigned.min);
    try testing.expectEqual(@as(i64, 255), unsigned.max);
}

// ============================================================================
// Set Operations (meet, join, widen)
// ============================================================================

test "ValueRange: meet (intersection)" {
    const r1 = ValueRange{ .min = 0, .max = 100, .bits = 32, .signed = true };
    const r2 = ValueRange{ .min = 50, .max = 150, .bits = 32, .signed = true };

    const result = r1.meet(r2);
    try testing.expectEqual(@as(i64, 50), result.min);
    try testing.expectEqual(@as(i64, 100), result.max);
}

test "ValueRange: meet produces empty on disjoint" {
    const r1 = ValueRange{ .min = 0, .max = 10, .bits = 32, .signed = true };
    const r2 = ValueRange{ .min = 20, .max = 30, .bits = 32, .signed = true };

    const result = r1.meet(r2);
    try testing.expect(result.isEmpty());
}

test "ValueRange: join (union)" {
    const r1 = ValueRange{ .min = 0, .max = 10, .bits = 32, .signed = true };
    const r2 = ValueRange{ .min = 20, .max = 30, .bits = 32, .signed = true };

    const result = r1.join(r2);
    try testing.expectEqual(@as(i64, 0), result.min);
    try testing.expectEqual(@as(i64, 30), result.max);
}

test "ValueRange: join with empty" {
    const r = ValueRange{ .min = 10, .max = 20, .bits = 32, .signed = true };
    const empty = ValueRange.empty(32, true);

    const result = r.join(empty);
    try testing.expectEqual(@as(i64, 10), result.min);
    try testing.expectEqual(@as(i64, 20), result.max);
}

test "ValueRange: widen expands to bound" {
    const old = ValueRange{ .min = 0, .max = 100, .bits = 32, .signed = true };
    const new = ValueRange{ .min = -10, .max = 200, .bits = 32, .signed = true };

    const result = old.widen(new);
    // min went negative, so widen to i32 min
    try testing.expectEqual(@as(i64, -2147483648), result.min);
    // max went higher, so widen to i32 max
    try testing.expectEqual(@as(i64, 2147483647), result.max);
}

// ============================================================================
// Arithmetic Operations
// ============================================================================

test "ValueRange: add" {
    const r1 = ValueRange{ .min = 10, .max = 20, .bits = 32, .signed = true };
    const r2 = ValueRange{ .min = 5, .max = 15, .bits = 32, .signed = true };

    const result = r1.add(r2);
    try testing.expectEqual(@as(i64, 15), result.min); // 10 + 5
    try testing.expectEqual(@as(i64, 35), result.max); // 20 + 15
}

test "ValueRange: add overflow becomes full range" {
    const r1 = ValueRange{ .min = 2147483640, .max = 2147483647, .bits = 32, .signed = true };
    const r2 = ValueRange{ .min = 10, .max = 20, .bits = 32, .signed = true };

    const result = r1.add(r2);
    // Overflow: should return full range
    try testing.expect(!result.isEmpty());
    try testing.expectEqual(@as(i64, -2147483648), result.min);
    try testing.expectEqual(@as(i64, 2147483647), result.max);
}

test "ValueRange: sub" {
    const r1 = ValueRange{ .min = 10, .max = 20, .bits = 32, .signed = true };
    const r2 = ValueRange{ .min = 5, .max = 8, .bits = 32, .signed = true };

    const result = r1.sub(r2);
    try testing.expectEqual(@as(i64, 2), result.min); // 10 - 8
    try testing.expectEqual(@as(i64, 15), result.max); // 20 - 5
}

test "ValueRange: mul positive ranges" {
    const r1 = ValueRange{ .min = 2, .max = 4, .bits = 32, .signed = true };
    const r2 = ValueRange{ .min = 3, .max = 5, .bits = 32, .signed = true };

    const result = r1.mul(r2);
    try testing.expectEqual(@as(i64, 6), result.min); // 2 * 3
    try testing.expectEqual(@as(i64, 20), result.max); // 4 * 5
}

test "ValueRange: mul with negative" {
    const r1 = ValueRange{ .min = -3, .max = 2, .bits = 32, .signed = true };
    const r2 = ValueRange{ .min = 4, .max = 5, .bits = 32, .signed = true };

    const result = r1.mul(r2);
    try testing.expectEqual(@as(i64, -15), result.min); // -3 * 5
    try testing.expectEqual(@as(i64, 10), result.max); // 2 * 5
}

// ============================================================================
// Bitwise Operations
// ============================================================================

test "ValueRange: bitAnd" {
    const r1 = ValueRange{ .min = 0, .max = 255, .bits = 32, .signed = false };
    const r2 = ValueRange{ .min = 0, .max = 15, .bits = 32, .signed = false };

    const result = r1.bitAnd(r2);
    try testing.expectEqual(@as(i64, 0), result.min);
    try testing.expectEqual(@as(i64, 15), result.max); // min of maxes
}

test "ValueRange: bitOr" {
    const r1 = ValueRange{ .min = 8, .max = 15, .bits = 32, .signed = false };
    const r2 = ValueRange{ .min = 4, .max = 7, .bits = 32, .signed = false };

    const result = r1.bitOr(r2);
    try testing.expectEqual(@as(i64, 8), result.min); // max of mins
}

// ============================================================================
// Shift Operations
// ============================================================================

test "ValueRange: shl" {
    const r = ValueRange{ .min = 1, .max = 4, .bits = 32, .signed = true };

    const result = r.shl(2);
    try testing.expectEqual(@as(i64, 4), result.min); // 1 << 2
    try testing.expectEqual(@as(i64, 16), result.max); // 4 << 2
}

test "ValueRange: ushr" {
    const r = ValueRange{ .min = 16, .max = 64, .bits = 32, .signed = false };

    const result = r.ushr(2);
    try testing.expectEqual(@as(i64, 4), result.min); // 16 >> 2
    try testing.expectEqual(@as(i64, 16), result.max); // 64 >> 2
}

test "ValueRange: sshr signed" {
    const r = ValueRange{ .min = -64, .max = -16, .bits = 32, .signed = true };

    const result = r.sshr(2);
    try testing.expectEqual(@as(i64, -16), result.min); // -64 >> 2
    try testing.expectEqual(@as(i64, -4), result.max); // -16 >> 2
}

// ============================================================================
// Comparison via meet
// ============================================================================

test "ValueRange: refine via meet for less than" {
    const r = ValueRange{ .min = -100, .max = 100, .bits = 32, .signed = true };
    // Simulate "x < 50" - meet with [-inf, 49]
    const constraint = ValueRange{ .min = -2147483648, .max = 49, .bits = 32, .signed = true };

    const refined = r.meet(constraint);
    try testing.expectEqual(@as(i64, -100), refined.min);
    try testing.expectEqual(@as(i64, 49), refined.max);
}

test "ValueRange: refine via meet for greater than" {
    const r = ValueRange{ .min = 0, .max = 100, .bits = 32, .signed = true };
    // Simulate "x > 75" - meet with [76, inf]
    const constraint = ValueRange{ .min = 76, .max = 2147483647, .bits = 32, .signed = true };

    const refined = r.meet(constraint);
    try testing.expectEqual(@as(i64, 76), refined.min);
    try testing.expectEqual(@as(i64, 100), refined.max);
}

test "ValueRange: refine via meet for equality" {
    const r = ValueRange{ .min = 0, .max = 100, .bits = 32, .signed = true };
    // Simulate "x == 42" - meet with [42, 42]
    const constraint = ValueRange.constant(42, 32, true);

    const refined = r.meet(constraint);
    try testing.expect(refined.isConstant());
    try testing.expectEqual(@as(?i64, 42), refined.getConstant());
}

test "ValueRange: meet produces empty on contradiction" {
    const r = ValueRange.constant(42, 32, true);
    // Simulate "x == 100" on x that is known to be 42
    const constraint = ValueRange.constant(100, 32, true);

    const refined = r.meet(constraint);
    try testing.expect(refined.isEmpty());
}

// ============================================================================
// Edge Cases
// ============================================================================

test "ValueRange: operations on empty" {
    const empty = ValueRange.empty(32, true);
    const r = ValueRange{ .min = 0, .max = 100, .bits = 32, .signed = true };

    // Operations with empty should return empty
    try testing.expect(empty.add(r).isEmpty());
    try testing.expect(empty.sub(r).isEmpty());
    try testing.expect(empty.mul(r).isEmpty());
    try testing.expect(empty.bitAnd(r).isEmpty());
}

test "ValueRange: constant folding via range" {
    const r1 = ValueRange.constant(10, 32, true);
    const r2 = ValueRange.constant(5, 32, true);

    const sum = r1.add(r2);
    try testing.expect(sum.isConstant());
    try testing.expectEqual(@as(?i64, 15), sum.getConstant());

    const diff = r1.sub(r2);
    try testing.expect(diff.isConstant());
    try testing.expectEqual(@as(?i64, 5), diff.getConstant());

    const prod = r1.mul(r2);
    try testing.expect(prod.isConstant());
    try testing.expectEqual(@as(?i64, 50), prod.getConstant());
}

test "ValueRange: 64-bit ranges" {
    const r = ValueRange.full(64, true);
    try testing.expectEqual(@as(i64, -9223372036854775808), r.min);
    try testing.expectEqual(@as(i64, 9223372036854775807), r.max);

    const u64_r = ValueRange.full(64, false);
    try testing.expectEqual(@as(i64, 0), u64_r.min);
    // Note: max i64 for unsigned 64-bit (we use i64 storage)
    try testing.expectEqual(@as(i64, 9223372036854775807), u64_r.max);
}
