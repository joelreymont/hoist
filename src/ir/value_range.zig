//! Value range analysis: track possible values of SSA values.
//! Enables optimizations: bounds check elimination, dead code elimination,
//! overflow check elimination, comparison simplification.

const std = @import("std");
const Type = @import("types.zig").Type;

/// Range of possible values for an SSA value.
/// Represents interval [min, max] with bit width and signedness.
pub const ValueRange = struct {
    /// Minimum possible value (signed interpretation).
    min: i64,

    /// Maximum possible value (signed interpretation).
    max: i64,

    /// Bit width of the value (8, 16, 32, 64).
    bits: u8,

    /// Whether this is a signed type.
    signed: bool,

    /// Empty range (unreachable code).
    pub fn empty(bits: u8, signed: bool) ValueRange {
        return .{
            .min = 1,
            .max = 0,
            .bits = bits,
            .signed = signed,
        };
    }

    /// Full range (unknown value).
    pub fn full(bits: u8, signed: bool) ValueRange {
        if (signed) {
            const half: i64 = @as(i64, 1) << @intCast(bits - 1);
            return .{
                .min = -half,
                .max = half - 1,
                .bits = bits,
                .signed = true,
            };
        } else {
            return .{
                .min = 0,
                .max = (@as(i64, 1) << @intCast(bits)) - 1,
                .bits = bits,
                .signed = false,
            };
        }
    }

    /// Single constant value.
    pub fn constant(value: i64, bits: u8, signed: bool) ValueRange {
        return .{
            .min = value,
            .max = value,
            .bits = bits,
            .signed = signed,
        };
    }

    /// Range from IR type.
    pub fn fromType(ty: Type) ValueRange {
        return switch (ty) {
            .i8 => full(8, true),
            .i16 => full(16, true),
            .i32 => full(32, true),
            .i64 => full(64, true),
            .f32, .f64 => unreachable, // No range analysis for floats
            .isize => full(64, true),
        };
    }

    /// Check if range is empty (unreachable).
    pub fn isEmpty(self: ValueRange) bool {
        return self.min > self.max;
    }

    /// Check if range contains single value.
    pub fn isConstant(self: ValueRange) bool {
        return self.min == self.max;
    }

    /// Get constant value if single value.
    pub fn getConstant(self: ValueRange) ?i64 {
        if (self.isConstant()) {
            return self.min;
        }
        return null;
    }

    /// Check if value is in range.
    pub fn contains(self: ValueRange, value: i64) bool {
        return value >= self.min and value <= self.max;
    }

    /// Intersection (meet): most precise range containing both.
    pub fn meet(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        const new_min = @max(self.min, other.min);
        const new_max = @min(self.max, other.max);

        return .{
            .min = new_min,
            .max = new_max,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Union (join): least precise range containing both.
    pub fn join(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty()) return other;
        if (other.isEmpty()) return self;

        return .{
            .min = @min(self.min, other.min),
            .max = @max(self.max, other.max),
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Widen: expand range to ensure fixpoint convergence.
    /// Used when range keeps growing during iteration.
    pub fn widen(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty()) return other;
        if (other.isEmpty()) return self;

        // If other exceeds self, widen to full range in that direction
        const new_min = if (other.min < self.min)
            self.minBound()
        else
            self.min;

        const new_max = if (other.max > self.max)
            self.maxBound()
        else
            self.max;

        return .{
            .min = new_min,
            .max = new_max,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Minimum bound for bit width and signedness.
    fn minBound(self: ValueRange) i64 {
        if (self.signed) {
            return -(@as(i64, 1) << @intCast(self.bits - 1));
        } else {
            return 0;
        }
    }

    /// Maximum bound for bit width and signedness.
    fn maxBound(self: ValueRange) i64 {
        if (self.signed) {
            return (@as(i64, 1) << @intCast(self.bits - 1)) - 1;
        } else {
            return (@as(i64, 1) << @intCast(self.bits)) - 1;
        }
    }

    /// Add two ranges (interval arithmetic).
    pub fn add(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty() or other.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        const min_sum = self.min + other.min;
        const max_sum = self.max + other.max;

        // Check for overflow
        const min_bound = self.minBound();
        const max_bound = self.maxBound();

        if (min_sum < min_bound or max_sum > max_bound) {
            // Overflow: return full range
            return full(self.bits, self.signed);
        }

        return .{
            .min = min_sum,
            .max = max_sum,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Subtract two ranges (interval arithmetic).
    pub fn sub(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty() or other.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        const min_diff = self.min - other.max;
        const max_diff = self.max - other.min;

        // Check for overflow
        const min_bound = self.minBound();
        const max_bound = self.maxBound();

        if (min_diff < min_bound or max_diff > max_bound) {
            return full(self.bits, self.signed);
        }

        return .{
            .min = min_diff,
            .max = max_diff,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Multiply two ranges (interval arithmetic).
    pub fn mul(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty() or other.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        // All four combinations of endpoints
        const products = [_]i64{
            self.min * other.min,
            self.min * other.max,
            self.max * other.min,
            self.max * other.max,
        };

        var min_prod: i64 = products[0];
        var max_prod: i64 = products[0];

        for (products[1..]) |p| {
            min_prod = @min(min_prod, p);
            max_prod = @max(max_prod, p);
        }

        const min_bound = self.minBound();
        const max_bound = self.maxBound();

        if (min_prod < min_bound or max_prod > max_bound) {
            return full(self.bits, self.signed);
        }

        return .{
            .min = min_prod,
            .max = max_prod,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Bitwise AND two ranges.
    pub fn bitAnd(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty() or other.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        // Conservative: AND can only make bits 0, so max is min of maxes
        // But min could be 0 (if any bit can be cleared)
        const new_max = @min(self.max, other.max);

        return .{
            .min = 0,
            .max = new_max,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Bitwise OR two ranges.
    pub fn bitOr(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty() or other.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        // Conservative: OR can only make bits 1, so min is max of mins
        const new_min = @max(self.min, other.min);
        const new_max = self.maxBound(); // Could set any bit

        return .{
            .min = new_min,
            .max = new_max,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Bitwise XOR two ranges.
    pub fn bitXor(self: ValueRange, other: ValueRange) ValueRange {
        std.debug.assert(self.bits == other.bits);
        std.debug.assert(self.signed == other.signed);

        if (self.isEmpty() or other.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        // Very conservative: XOR can produce any value
        return full(self.bits, self.signed);
    }

    /// Left shift by constant amount.
    pub fn shl(self: ValueRange, shift: u6) ValueRange {
        if (self.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        const shift_amt: i64 = @intCast(shift);
        const new_min = self.min << shift_amt;
        const new_max = self.max << shift_amt;

        const min_bound = self.minBound();
        const max_bound = self.maxBound();

        if (new_min < min_bound or new_max > max_bound) {
            return full(self.bits, self.signed);
        }

        return .{
            .min = new_min,
            .max = new_max,
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Unsigned right shift by constant amount.
    pub fn ushr(self: ValueRange, shift: u6) ValueRange {
        if (self.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        const shift_amt: u6 = @intCast(shift);
        const new_min = @as(u64, @bitCast(self.min)) >> shift_amt;
        const new_max = @as(u64, @bitCast(self.max)) >> shift_amt;

        return .{
            .min = @bitCast(new_min),
            .max = @bitCast(new_max),
            .bits = self.bits,
            .signed = self.signed,
        };
    }

    /// Signed right shift by constant amount.
    pub fn sshr(self: ValueRange, shift: u6) ValueRange {
        if (self.isEmpty()) {
            return empty(self.bits, self.signed);
        }

        const shift_amt: i64 = @intCast(shift);
        const new_min = self.min >> shift_amt;
        const new_max = self.max >> shift_amt;

        return .{
            .min = new_min,
            .max = new_max,
            .bits = self.bits,
            .signed = self.signed,
        };
    }
};
