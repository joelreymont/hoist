//! Type legalization for target ISAs.
//!
//! Converts unsupported types to legal ones based on target capabilities.
//! Implements strategies:
//! - Promote: Widen to supported type (i8 -> i32)
//! - Expand: Split into multiple operations (i128 -> two i64s)
//! - Split: Split vectors into smaller vectors
//! - Widen: Combine narrow vectors into wider vectors

const std = @import("std");
const Type = @import("../ir/types.zig").Type;
const Allocator = std.mem.Allocator;

/// Type legalization action for a given type.
pub const TypeAction = enum {
    /// Type is legal as-is, no action needed.
    legal,
    /// Promote to wider type (i8 -> i32).
    promote,
    /// Expand to multiple values (i128 -> i64, i64).
    expand,
    /// Split vector into narrower vectors (i32x8 -> i32x4, i32x4).
    split_vector,
    /// Widen vector to wider vector (i32x2 -> i32x4 with zeros).
    widen_vector,
};

/// Type legalization strategy result.
pub const LegalizeAction = struct {
    action: TypeAction,
    /// Target type for promote/widen, or half-width type for split.
    target_type: Type,
};

/// Type legalization configuration for a target.
pub const TypeLegalizer = struct {
    /// Minimum legal integer width (typically 32 bits).
    min_int_width: u32,
    /// Maximum legal integer width (typically 64 bits, or 128 for some targets).
    max_int_width: u32,
    /// Legal vector sizes (in bits).
    legal_vector_sizes: []const u32,
    /// Whether to support i128.
    support_i128: bool,

    /// Default configuration for most 64-bit targets.
    pub fn default64() TypeLegalizer {
        return .{
            .min_int_width = 32,
            .max_int_width = 64,
            .legal_vector_sizes = &.{ 128, 256 },
            .support_i128 = false,
        };
    }

    /// AArch64 configuration (supports i8/i16 natively in registers).
    pub fn aarch64() TypeLegalizer {
        return .{
            .min_int_width = 8, // AArch64 can handle i8/i16 natively
            .max_int_width = 64,
            .legal_vector_sizes = &.{ 64, 128 }, // D and Q registers
            .support_i128 = true, // Via register pairs
        };
    }

    /// x86-64 configuration.
    pub fn x86_64() TypeLegalizer {
        return .{
            .min_int_width = 32, // Promote i8/i16 to i32
            .max_int_width = 64,
            .legal_vector_sizes = &.{ 128, 256, 512 }, // SSE, AVX, AVX-512
            .support_i128 = false,
        };
    }

    /// Determine legalization action for a scalar integer type.
    fn legalizeIntScalar(self: *const TypeLegalizer, ty: Type) LegalizeAction {
        std.debug.assert(ty.isInt() and !ty.isVector());

        const width = ty.bits();

        // Check if already legal
        if (width >= self.min_int_width and width <= self.max_int_width) {
            // Common legal widths: 8, 16, 32, 64 (depending on min_int_width)
            if (width == 8 or width == 16 or width == 32 or width == 64) {
                return .{ .action = .legal, .target_type = ty };
            }
        }

        // i128 handling
        if (width == 128) {
            if (self.support_i128) {
                return .{ .action = .legal, .target_type = ty };
            } else {
                // Expand to two i64 operations
                return .{ .action = .expand, .target_type = Type.I64 };
            }
        }

        // Too narrow - promote to min width
        if (width < self.min_int_width) {
            const target_type = Type.int(@intCast(self.min_int_width)) orelse Type.I32;
            return .{ .action = .promote, .target_type = target_type };
        }

        // Too wide - expand
        if (width > self.max_int_width) {
            // Expand to max width
            const target_type = Type.int(@intCast(self.max_int_width)) orelse Type.I64;
            return .{ .action = .expand, .target_type = target_type };
        }

        // Odd widths - promote to next power of 2
        const next_pow2 = std.math.ceilPowerOfTwo(u32, width) catch self.max_int_width;
        if (next_pow2 <= self.max_int_width) {
            const target_type = Type.int(@intCast(next_pow2)) orelse Type.I32;
            return .{ .action = .promote, .target_type = target_type };
        }

        // Fallback: expand to max width
        const target_type = Type.int(@intCast(self.max_int_width)) orelse Type.I64;
        return .{ .action = .expand, .target_type = target_type };
    }

    /// Determine legalization action for a scalar float type.
    fn legalizeFloatScalar(self: *const TypeLegalizer, ty: Type) LegalizeAction {
        _ = self;
        std.debug.assert(ty.isFloat() and !ty.isVector());

        // Most targets support f32 and f64 natively
        if (ty.eql(Type.F32) or ty.eql(Type.F64)) {
            return .{ .action = .legal, .target_type = ty };
        }

        // f16 - promote to f32
        if (ty.eql(Type.F16)) {
            return .{ .action = .promote, .target_type = Type.F32 };
        }

        // f128 - expand to library calls (represented as expand to f64)
        if (ty.eql(Type.F128)) {
            return .{ .action = .expand, .target_type = Type.F64 };
        }

        // Unknown float type - default to legal
        return .{ .action = .legal, .target_type = ty };
    }

    /// Determine legalization action for a vector type.
    fn legalizeVector(self: *const TypeLegalizer, ty: Type) LegalizeAction {
        std.debug.assert(ty.isVector());

        const total_bits = ty.bits();
        const lane_count = ty.laneCount();
        const lane_type = ty.laneType();

        // First, check if vector size is legal
        var is_legal_size = false;
        for (self.legal_vector_sizes) |legal_size| {
            if (total_bits == legal_size) {
                is_legal_size = true;
                break;
            }
        }

        if (is_legal_size) {
            // Size is legal, but check lane type
            const lane_action = if (lane_type.isInt())
                self.legalizeIntScalar(lane_type)
            else
                self.legalizeFloatScalar(lane_type);

            if (lane_action.action == .legal) {
                return .{ .action = .legal, .target_type = ty };
            }
        }

        // Vector is too wide - split into smaller vectors
        if (self.legal_vector_sizes.len > 0) {
            const max_legal_size = self.legal_vector_sizes[self.legal_vector_sizes.len - 1];
            if (total_bits > max_legal_size) {
                // Split in half
                const half_lanes = lane_count / 2;
                if (half_lanes > 0) {
                    // Construct half-width vector type
                    const log2_half = std.math.log2_int(u32, half_lanes);
                    const half_type = Type{
                        .raw = (lane_type.raw & 0x0f) | (@as(u16, log2_half) << 4) | 0x80,
                    };
                    return .{ .action = .split_vector, .target_type = half_type };
                }
            }
        }

        // Vector is too narrow - widen to legal size
        if (self.legal_vector_sizes.len > 0 and total_bits < self.legal_vector_sizes[0]) {
            const min_legal_size = self.legal_vector_sizes[0];
            const lane_bits = lane_type.bits();
            const target_lanes = min_legal_size / lane_bits;
            if (target_lanes > lane_count and target_lanes <= 256) {
                const log2_target = std.math.log2_int(u32, @intCast(target_lanes));
                const wide_type = Type{
                    .raw = (lane_type.raw & 0x0f) | (@as(u16, log2_target) << 4) | 0x80,
                };
                return .{ .action = .widen_vector, .target_type = wide_type };
            }
        }

        // Default: legal as-is
        return .{ .action = .legal, .target_type = ty };
    }

    /// Determine legalization action for any type.
    pub fn legalize(self: *const TypeLegalizer, ty: Type) LegalizeAction {
        if (ty.isInvalid() or ty.isSpecial()) {
            return .{ .action = .legal, .target_type = ty };
        }

        if (ty.isVector()) {
            return self.legalizeVector(ty);
        }

        if (ty.isInt()) {
            return self.legalizeIntScalar(ty);
        }

        if (ty.isFloat()) {
            return self.legalizeFloatScalar(ty);
        }

        // Unknown type - assume legal
        return .{ .action = .legal, .target_type = ty };
    }

    /// Check if type is legal without computing full action.
    pub fn isLegal(self: *const TypeLegalizer, ty: Type) bool {
        const action = self.legalize(ty);
        return action.action == .legal;
    }
};

// ============================================================================
// Integer widening/narrowing utilities
// ============================================================================

/// Widen integer type to target width.
pub fn widenInt(ty: Type, target_width: u32) ?Type {
    if (!ty.isInt()) return null;
    if (target_width > 65535) return null;
    return Type.int(@intCast(target_width));
}

/// Narrow integer type to target width.
pub fn narrowInt(ty: Type, target_width: u32) ?Type {
    if (!ty.isInt()) return null;
    if (target_width >= ty.bits()) return null;
    if (target_width > 65535) return null;
    return Type.int(@intCast(target_width));
}

/// Get next power-of-two width for integer type.
pub fn nextPow2Width(ty: Type) ?Type {
    if (!ty.isInt()) return null;
    const width = ty.bits();
    const next = std.math.ceilPowerOfTwo(u32, width + 1) catch return null;
    if (next > 65535) return null;
    return Type.int(@intCast(next));
}

// ============================================================================
// Vector type utilities
// ============================================================================

/// Split vector type in half.
pub fn splitVectorHalf(ty: Type) ?Type {
    if (!ty.isVector()) return null;
    const lanes = ty.laneCount();
    if (lanes <= 1) return null;
    return Type.vector(ty.laneType(), lanes / 2);
}

/// Double vector lane count.
pub fn widenVector(ty: Type) ?Type {
    if (!ty.isVector()) return null;
    const lanes = ty.laneCount();
    const double_lanes = std.math.mul(u32, lanes, 2) catch return null;
    if (double_lanes > 256) return null; // Max lanes
    return Type.vector(ty.laneType(), double_lanes);
}

/// Create vector type with specific lane count.
pub fn vectorType(lane_type: Type, lane_count: u32) ?Type {
    return Type.vector(lane_type, lane_count);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "TypeLegalizer: default64 config" {
    const legalizer = TypeLegalizer.default64();
    try testing.expectEqual(@as(u32, 32), legalizer.min_int_width);
    try testing.expectEqual(@as(u32, 64), legalizer.max_int_width);
    try testing.expect(!legalizer.support_i128);
}

test "TypeLegalizer: aarch64 config" {
    const legalizer = TypeLegalizer.aarch64();
    try testing.expectEqual(@as(u32, 8), legalizer.min_int_width);
    try testing.expectEqual(@as(u32, 64), legalizer.max_int_width);
    try testing.expect(legalizer.support_i128);
}

test "TypeLegalizer: x86_64 config" {
    const legalizer = TypeLegalizer.x86_64();
    try testing.expectEqual(@as(u32, 32), legalizer.min_int_width);
    try testing.expectEqual(@as(u32, 64), legalizer.max_int_width);
    try testing.expect(!legalizer.support_i128);
}

test "TypeLegalizer: legal scalar integers" {
    const legalizer = TypeLegalizer.default64();

    const i32_action = legalizer.legalize(Type.I32);
    try testing.expectEqual(TypeAction.legal, i32_action.action);
    try testing.expect(i32_action.target_type.eql(Type.I32));

    const i64_action = legalizer.legalize(Type.I64);
    try testing.expectEqual(TypeAction.legal, i64_action.action);
    try testing.expect(i64_action.target_type.eql(Type.I64));
}

test "TypeLegalizer: promote narrow integers" {
    const legalizer = TypeLegalizer.default64();

    const i8_action = legalizer.legalize(Type.I8);
    try testing.expectEqual(TypeAction.promote, i8_action.action);
    try testing.expect(i8_action.target_type.eql(Type.I32));

    const i16_action = legalizer.legalize(Type.I16);
    try testing.expectEqual(TypeAction.promote, i16_action.action);
    try testing.expect(i16_action.target_type.eql(Type.I32));
}

test "TypeLegalizer: expand i128 when not supported" {
    const legalizer = TypeLegalizer.default64();

    const i128_action = legalizer.legalize(Type.I128);
    try testing.expectEqual(TypeAction.expand, i128_action.action);
    try testing.expect(i128_action.target_type.eql(Type.I64));
}

test "TypeLegalizer: i128 legal on aarch64" {
    const legalizer = TypeLegalizer.aarch64();

    const i128_action = legalizer.legalize(Type.I128);
    try testing.expectEqual(TypeAction.legal, i128_action.action);
    try testing.expect(i128_action.target_type.eql(Type.I128));
}

test "TypeLegalizer: aarch64 allows i8/i16" {
    const legalizer = TypeLegalizer.aarch64();

    const i8_action = legalizer.legalize(Type.I8);
    try testing.expectEqual(TypeAction.legal, i8_action.action);

    const i16_action = legalizer.legalize(Type.I16);
    try testing.expectEqual(TypeAction.legal, i16_action.action);
}

test "TypeLegalizer: legal floats" {
    const legalizer = TypeLegalizer.default64();

    const f32_action = legalizer.legalize(Type.F32);
    try testing.expectEqual(TypeAction.legal, f32_action.action);

    const f64_action = legalizer.legalize(Type.F64);
    try testing.expectEqual(TypeAction.legal, f64_action.action);
}

test "TypeLegalizer: promote f16" {
    const legalizer = TypeLegalizer.default64();

    const f16_action = legalizer.legalize(Type.F16);
    try testing.expectEqual(TypeAction.promote, f16_action.action);
    try testing.expect(f16_action.target_type.eql(Type.F32));
}

test "TypeLegalizer: expand f128" {
    const legalizer = TypeLegalizer.default64();

    const f128_action = legalizer.legalize(Type.F128);
    try testing.expectEqual(TypeAction.expand, f128_action.action);
    try testing.expect(f128_action.target_type.eql(Type.F64));
}

test "TypeLegalizer: legal vectors" {
    const legalizer = TypeLegalizer.default64();

    const i32x4_action = legalizer.legalize(Type.I32X4);
    try testing.expectEqual(TypeAction.legal, i32x4_action.action);
}

test "TypeLegalizer: isLegal shortcut" {
    const legalizer = TypeLegalizer.default64();

    try testing.expect(legalizer.isLegal(Type.I32));
    try testing.expect(legalizer.isLegal(Type.I64));
    try testing.expect(legalizer.isLegal(Type.F32));
    try testing.expect(legalizer.isLegal(Type.F64));
    try testing.expect(!legalizer.isLegal(Type.I8));
    try testing.expect(!legalizer.isLegal(Type.I128));
}

test "widenInt: basic widening" {
    const result = widenInt(Type.I32, 64);
    try testing.expect(result != null);
    try testing.expect(result.?.eql(Type.I64));

    const i8_widen = widenInt(Type.I8, 32);
    try testing.expect(i8_widen != null);
    try testing.expect(i8_widen.?.eql(Type.I32));
}

test "widenInt: invalid for non-int" {
    const result = widenInt(Type.F32, 64);
    try testing.expect(result == null);
}

test "narrowInt: basic narrowing" {
    const result = narrowInt(Type.I64, 32);
    try testing.expect(result != null);
    try testing.expect(result.?.eql(Type.I32));

    const i32_narrow = narrowInt(Type.I32, 16);
    try testing.expect(i32_narrow != null);
    try testing.expect(i32_narrow.?.eql(Type.I16));
}

test "narrowInt: cannot widen" {
    const result = narrowInt(Type.I32, 64);
    try testing.expect(result == null);
}

test "nextPow2Width: rounds up" {
    const i32_next = nextPow2Width(Type.I32);
    try testing.expect(i32_next != null);
    try testing.expect(i32_next.?.eql(Type.I64));

    const i8_next = nextPow2Width(Type.I8);
    try testing.expect(i8_next != null);
    try testing.expect(i8_next.?.eql(Type.I16));
}

test "splitVectorHalf: halves lane count" {
    const i32x4 = Type.I32X4;
    const half = splitVectorHalf(i32x4);
    try testing.expect(half != null);
    try testing.expectEqual(@as(u32, 2), half.?.laneCount());
    try testing.expect(half.?.laneType().eql(Type.I32));
}

test "splitVectorHalf: fails on scalar" {
    const result = splitVectorHalf(Type.I32);
    try testing.expect(result == null);
}

test "widenVector: doubles lane count" {
    const i32x2 = vectorType(Type.I32, 2);
    try testing.expect(i32x2 != null);

    const wide = widenVector(i32x2.?);
    try testing.expect(wide != null);
    try testing.expectEqual(@as(u32, 4), wide.?.laneCount());
    try testing.expect(wide.?.laneType().eql(Type.I32));
}

test "widenVector: respects max lanes" {
    const i32x128 = vectorType(Type.I32, 128);
    try testing.expect(i32x128 != null);

    const wide = widenVector(i32x128.?);
    try testing.expect(wide != null);

    const too_wide = widenVector(wide.?);
    try testing.expect(too_wide == null); // Can't exceed 256 lanes
}

test "vectorType: creates valid vectors" {
    const v2 = vectorType(Type.I32, 2);
    try testing.expect(v2 != null);
    try testing.expectEqual(@as(u32, 2), v2.?.laneCount());

    const v4 = vectorType(Type.I32, 4);
    try testing.expect(v4 != null);
    try testing.expectEqual(@as(u32, 4), v4.?.laneCount());

    const v16 = vectorType(Type.I8, 16);
    try testing.expect(v16 != null);
    try testing.expectEqual(@as(u32, 16), v16.?.laneCount());
}

test "vectorType: rejects invalid lane counts" {
    const v1 = vectorType(Type.I32, 1); // Too few
    try testing.expect(v1 == null);

    const v3 = vectorType(Type.I32, 3); // Not power of 2
    try testing.expect(v3 == null);

    const v512 = vectorType(Type.I32, 512); // Too many
    try testing.expect(v512 == null);
}

test "vectorType: rejects non-lane types" {
    const result = vectorType(Type.I32X4, 4);
    try testing.expect(result == null); // I32X4 is already a vector
}
