//! AArch64-specific legalization hooks.
//!
//! Implements target-specific legalization for:
//! - Conditional select expansion for unsupported conditions
//! - Addressing mode legalization (ensure offsets fit in instruction encoding)
//! - Immediate value legalization (use literal pool for large constants)
//! - Vector element size constraints
//!
//! Reference: Cranelift's AArch64 legalization

const std = @import("std");
const Allocator = std.mem.Allocator;
const Type = @import("../../ir/types.zig").Type;
const IntCC = @import("../../ir/condcodes.zig").IntCC;
const FloatCC = @import("../../ir/condcodes.zig").FloatCC;
const CondCode = @import("inst.zig").CondCode;
const Imm12 = @import("inst.zig").Imm12;
const ImmLogic = @import("inst.zig").ImmLogic;
const OperandSize = @import("inst.zig").OperandSize;
const LiteralPool = @import("encoding.zig").LiteralPool;

// ============================================================================
// Conditional Code Mapping
// ============================================================================

/// Map IntCC to AArch64 condition code.
/// Returns null if the condition requires special handling.
pub fn intCCToCondCode(cc: IntCC) CondCode {
    return switch (cc) {
        .eq => .eq,
        .ne => .ne,
        .slt => .lt,
        .sge => .ge,
        .sgt => .gt,
        .sle => .le,
        .ult => .cc, // Carry clear (unsigned <)
        .uge => .cs, // Carry set (unsigned >=)
        .ugt => .hi, // Higher (unsigned >)
        .ule => .ls, // Lower or same (unsigned <=)
    };
}

/// Map FloatCC to AArch64 condition code.
/// Returns null if the condition requires special handling (e.g., unordered cases).
pub fn floatCCToCondCode(cc: FloatCC) ?CondCode {
    return switch (cc) {
        .eq => .eq, // Equal (ordered)
        .ne => .ne, // Not equal
        .lt => .mi, // Less than (FCMP sets N flag for LT)
        .le => .ls, // Less than or equal
        .gt => .gt, // Greater than
        .ge => .ge, // Greater than or equal
        // Unordered variants require complex handling
        .uno => .vs, // Unordered (overflow flag set when either operand is NaN)
        .ord => .vc, // Ordered (no overflow when both operands are non-NaN)
        .ueq => null, // Unordered or equal (requires multi-instruction sequence)
        .one => null, // Ordered and not equal (requires multi-instruction sequence)
        .ult => null, // Unordered or less than
        .ule => null, // Unordered or less than or equal
        .ugt => null, // Unordered or greater than
        .uge => null, // Unordered or greater than or equal
    };
}

/// Check if float condition code requires expansion.
pub fn floatCCRequiresExpansion(cc: FloatCC) bool {
    return floatCCToCondCode(cc) == null;
}

/// Expansion strategy for floating-point comparisons.
pub const FloatCCExpansion = union(enum) {
    /// Single comparison with given condition code.
    single: CondCode,
    /// Two comparisons combined with OR logic (e.g., unordered OR equal).
    or_pair: struct {
        first: CondCode,
        second: CondCode,
    },
    /// Two comparisons combined with AND logic (e.g., ordered AND not-equal).
    and_pair: struct {
        first: CondCode,
        second: CondCode,
    },
};

/// Get expansion strategy for floating-point comparison.
pub fn expandFloatCC(cc: FloatCC) FloatCCExpansion {
    return switch (cc) {
        // Direct mappings
        .eq => .{ .single = .eq },
        .ne => .{ .single = .ne },
        .lt => .{ .single = .mi },
        .le => .{ .single = .ls },
        .gt => .{ .single = .gt },
        .ge => .{ .single = .ge },
        .uno => .{ .single = .vs },
        .ord => .{ .single = .vc },

        // Unordered-or-equal: (unordered) OR (equal)
        .ueq => .{ .or_pair = .{ .first = .vs, .second = .eq } },

        // Ordered-and-not-equal: (ordered) AND (not-equal)
        .one => .{ .and_pair = .{ .first = .vc, .second = .ne } },

        // Unordered-or-less-than: (unordered) OR (less-than)
        .ult => .{ .or_pair = .{ .first = .vs, .second = .mi } },

        // Unordered-or-less-equal: (unordered) OR (less-equal)
        .ule => .{ .or_pair = .{ .first = .vs, .second = .ls } },

        // Unordered-or-greater-than: (unordered) OR (greater-than)
        .ugt => .{ .or_pair = .{ .first = .vs, .second = .gt } },

        // Unordered-or-greater-equal: (unordered) OR (greater-equal)
        .uge => .{ .or_pair = .{ .first = .vs, .second = .ge } },
    };
}

// ============================================================================
// Immediate Legalization
// ============================================================================

/// Result of immediate legalization.
pub const ImmLegalization = union(enum) {
    /// Immediate is valid, use as-is.
    valid,
    /// Immediate requires literal pool.
    literal_pool,
    /// Immediate can be synthesized with MOV sequence (MOVZ/MOVK).
    synthesize_mov,
    /// Immediate can be negated and used with inverted operation.
    negate,
};

/// Check if value fits in 12-bit arithmetic immediate.
pub fn isValidArithImm(value: u64) bool {
    return Imm12.maybeFromU64(value) != null;
}

/// Check if value is valid logical immediate.
pub fn isValidLogicalImm(value: u64, size: OperandSize) bool {
    return ImmLogic.maybeFromU64(value, size) != null;
}

/// Legalize immediate value for arithmetic operations (ADD/SUB).
pub fn legalizeArithImm(value: u64) ImmLegalization {
    // Check if fits in 12-bit immediate (with optional shift)
    if (isValidArithImm(value)) {
        return .valid;
    }

    // Check if negated value fits
    const negated = @as(u64, @bitCast(-@as(i64, @bitCast(value))));
    if (isValidArithImm(negated)) {
        return .negate;
    }

    // Try to synthesize with MOV sequence
    if (canSynthesizeWithMov(value)) {
        return .synthesize_mov;
    }

    // Fallback to literal pool
    return .literal_pool;
}

/// Legalize immediate value for logical operations (AND/ORR/EOR).
pub fn legalizeLogicalImm(value: u64, size: OperandSize) ImmLegalization {
    if (isValidLogicalImm(value, size)) {
        return .valid;
    }

    // Check if inverted value is valid (for complement optimization)
    const inverted = ~value;
    if (isValidLogicalImm(inverted, size)) {
        return .negate;
    }

    // Try MOV synthesis
    if (canSynthesizeWithMov(value)) {
        return .synthesize_mov;
    }

    return .literal_pool;
}

/// Check if value can be synthesized with MOVZ/MOVK sequence.
/// Values that fit in 1-4 MOVZ/MOVK instructions are considered synthesizable.
fn canSynthesizeWithMov(value: u64) bool {
    if (value == 0) return true;

    // Count non-zero 16-bit chunks
    var chunks: u8 = 0;
    var v = value;
    var i: u8 = 0;
    while (i < 4) : (i += 1) {
        if ((v & 0xFFFF) != 0) {
            chunks += 1;
        }
        v >>= 16;
    }

    // Can synthesize with up to 4 instructions (MOVZ + 3x MOVK)
    // For practical purposes, limit to 2-3 chunks for code size
    return chunks <= 3;
}

/// Calculate how many MOV instructions needed to synthesize value.
pub fn countMovInstructions(value: u64) u8 {
    if (value == 0) return 1; // Single MOVZ

    var chunks: u8 = 0;
    var v = value;
    var i: u8 = 0;
    while (i < 4) : (i += 1) {
        if ((v & 0xFFFF) != 0) {
            chunks += 1;
        }
        v >>= 16;
    }
    return chunks;
}

// ============================================================================
// Addressing Mode Legalization
// ============================================================================

/// Addressing mode constraints for AArch64 load/store.
pub const AddressingMode = union(enum) {
    /// Register + immediate offset (must be aligned and fit in scaled 12-bit).
    reg_imm: struct {
        max_offset: i64,
        alignment: u32,
    },
    /// Register + register offset.
    reg_reg,
    /// Register + extended register (SXTW/UXTW).
    reg_extended,
    /// Pre-indexed: [base, #offset]! (offset in range -256 to 255).
    pre_indexed,
    /// Post-indexed: [base], #offset (offset in range -256 to 255).
    post_indexed,
};

/// Check if offset is valid for load/store instruction.
/// access_size: size in bytes (1, 2, 4, 8, 16).
pub fn isValidLoadStoreOffset(offset: i64, access_size: u32) bool {
    // Must be aligned to access size
    if (@as(u64, @bitCast(offset)) & (access_size - 1) != 0) {
        return false;
    }

    // Must fit in unsigned 12-bit scaled immediate
    // Range: 0 to (4095 * access_size)
    if (offset < 0) {
        return false;
    }

    const max_offset = 4095 * @as(i64, access_size);
    return offset <= max_offset;
}

/// Check if offset is valid for pre/post-indexed addressing.
/// Range: -256 to 255 (9-bit signed immediate).
pub fn isValidIndexedOffset(offset: i64) bool {
    return offset >= -256 and offset <= 255;
}

/// Legalize addressing mode offset.
pub fn legalizeOffset(offset: i64, access_size: u32) union(enum) {
    valid: void,
    materialize_base: void, // Compute new base address
    split_offset: struct { // Split into base adjustment + small offset
        base_adjust: i64,
        remaining: i64,
    },
} {
    if (isValidLoadStoreOffset(offset, access_size)) {
        return .valid;
    }

    // Try to split into aligned base + small offset
    const align_mask = @as(i64, access_size) - 1;
    const aligned_offset = offset & ~align_mask;
    const remaining = offset & align_mask;

    if (isValidLoadStoreOffset(remaining, access_size)) {
        return .{ .split_offset = .{
            .base_adjust = aligned_offset,
            .remaining = remaining,
        } };
    }

    // Fallback: materialize into register
    return .materialize_base;
}

// ============================================================================
// Conditional Select Expansion
// ============================================================================

/// Strategy for conditional select expansion.
pub const CondSelectExpansion = union(enum) {
    /// Native CSEL instruction.
    native: CondCode,
    /// Requires expansion to compare + branch + select sequence.
    expand,
};

/// Determine if conditional select needs expansion.
pub fn condSelectStrategy(cc: IntCC) CondSelectExpansion {
    // All integer conditions map directly to CSEL
    const cond = intCCToCondCode(cc);
    return .{ .native = cond };
}

/// Determine if floating-point conditional select needs expansion.
pub fn floatCondSelectStrategy(cc: FloatCC) CondSelectExpansion {
    if (floatCCToCondCode(cc)) |cond| {
        return .{ .native = cond };
    }
    // Unordered conditions require expansion
    return .expand;
}

// ============================================================================
// Vector Legalization
// ============================================================================

/// Vector element size constraints.
pub const VectorLegalization = union(enum) {
    /// Vector operation is supported natively.
    supported,
    /// Unsupported element size, requires scalarization.
    scalarize,
    /// Unsupported vector width, requires splitting.
    split,
};

/// Check if vector element size is supported for operation.
pub fn checkVectorElementSize(ty: Type) VectorLegalization {
    if (!ty.isVector()) {
        return .supported;
    }

    const elem_bits = ty.laneType().bits();
    const lane_count = ty.laneCount();

    // AArch64 NEON supports 8, 16, 32, 64-bit elements
    if (elem_bits != 8 and elem_bits != 16 and elem_bits != 32 and elem_bits != 64) {
        return .scalarize;
    }

    // Total vector size must be 64 or 128 bits
    const total_bits = elem_bits * lane_count;
    if (total_bits != 64 and total_bits != 128) {
        if (total_bits < 64) {
            return .scalarize;
        } else {
            return .split;
        }
    }

    return .supported;
}

/// Check if vector type requires legalization.
pub fn requiresVectorLegalization(ty: Type) bool {
    return checkVectorElementSize(ty) != .supported;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "intCCToCondCode: all conditions map correctly" {
    try testing.expectEqual(CondCode.eq, intCCToCondCode(.eq));
    try testing.expectEqual(CondCode.ne, intCCToCondCode(.ne));
    try testing.expectEqual(CondCode.lt, intCCToCondCode(.slt));
    try testing.expectEqual(CondCode.ge, intCCToCondCode(.sge));
    try testing.expectEqual(CondCode.gt, intCCToCondCode(.sgt));
    try testing.expectEqual(CondCode.le, intCCToCondCode(.sle));
    try testing.expectEqual(CondCode.cc, intCCToCondCode(.ult));
    try testing.expectEqual(CondCode.cs, intCCToCondCode(.uge));
    try testing.expectEqual(CondCode.hi, intCCToCondCode(.ugt));
    try testing.expectEqual(CondCode.ls, intCCToCondCode(.ule));
}

test "floatCCToCondCode: ordered conditions map" {
    try testing.expectEqual(CondCode.eq, floatCCToCondCode(.eq).?);
    try testing.expectEqual(CondCode.ne, floatCCToCondCode(.ne).?);
    try testing.expectEqual(CondCode.mi, floatCCToCondCode(.lt).?);
    try testing.expectEqual(CondCode.gt, floatCCToCondCode(.gt).?);
}

test "floatCCToCondCode: unordered conditions return null" {
    try testing.expect(floatCCToCondCode(.ueq) == null);
    try testing.expect(floatCCToCondCode(.one) == null);
    try testing.expect(floatCCToCondCode(.ult) == null);
}

test "floatCCRequiresExpansion: identifies unordered variants" {
    try testing.expect(!floatCCRequiresExpansion(.eq));
    try testing.expect(!floatCCRequiresExpansion(.lt));
    try testing.expect(floatCCRequiresExpansion(.ueq));
    try testing.expect(floatCCRequiresExpansion(.ult));
}

test "isValidArithImm: valid 12-bit immediates" {
    try testing.expect(isValidArithImm(0));
    try testing.expect(isValidArithImm(42));
    try testing.expect(isValidArithImm(4095));
    try testing.expect(isValidArithImm(4096)); // 1 << 12
    try testing.expect(isValidArithImm(0xABC000)); // fits with shift
}

test "isValidArithImm: invalid immediates" {
    try testing.expect(!isValidArithImm(0x1000000)); // too large
    try testing.expect(!isValidArithImm(0x1001)); // not aligned for shift
    try testing.expect(!isValidArithImm(0xABCDEF)); // doesn't fit
}

test "legalizeArithImm: valid immediate" {
    const result = legalizeArithImm(100);
    try testing.expectEqual(ImmLegalization.valid, result);
}

test "legalizeArithImm: requires negation" {
    // Large value that when negated fits
    const value = @as(u64, @bitCast(-@as(i64, 100)));
    const result = legalizeArithImm(value);
    // Either valid or negate depending on magnitude
    try testing.expect(result == .valid or result == .negate);
}

test "legalizeArithImm: requires synthesis or pool" {
    const result = legalizeArithImm(0x123456789ABC);
    // Should either synthesize or use literal pool
    try testing.expect(result == .synthesize_mov or result == .literal_pool);
}

test "canSynthesizeWithMov: simple values" {
    try testing.expect(canSynthesizeWithMov(0));
    try testing.expect(canSynthesizeWithMov(0x1234)); // 1 chunk
    try testing.expect(canSynthesizeWithMov(0x12340000)); // 1 chunk shifted
    try testing.expect(canSynthesizeWithMov(0x1234000056780000)); // 2 chunks
}

test "canSynthesizeWithMov: complex values" {
    // 4 chunks - at the limit
    try testing.expect(!canSynthesizeWithMov(0x1234567890ABCDEF));
}

test "countMovInstructions: zero" {
    try testing.expectEqual(@as(u8, 1), countMovInstructions(0));
}

test "countMovInstructions: single chunk" {
    try testing.expectEqual(@as(u8, 1), countMovInstructions(0x1234));
    try testing.expectEqual(@as(u8, 1), countMovInstructions(0x56780000));
}

test "countMovInstructions: multiple chunks" {
    try testing.expectEqual(@as(u8, 2), countMovInstructions(0x12340000ABCD));
    try testing.expectEqual(@as(u8, 4), countMovInstructions(0x1234567890ABCDEF));
}

test "isValidLoadStoreOffset: valid offsets" {
    try testing.expect(isValidLoadStoreOffset(0, 8));
    try testing.expect(isValidLoadStoreOffset(8, 8));
    try testing.expect(isValidLoadStoreOffset(4095 * 8, 8)); // max for 8-byte
    try testing.expect(isValidLoadStoreOffset(16, 4));
}

test "isValidLoadStoreOffset: invalid offsets" {
    try testing.expect(!isValidLoadStoreOffset(-8, 8)); // negative
    try testing.expect(!isValidLoadStoreOffset(4, 8)); // misaligned
    try testing.expect(!isValidLoadStoreOffset(4096 * 8, 8)); // too large
}

test "isValidIndexedOffset: valid range" {
    try testing.expect(isValidIndexedOffset(0));
    try testing.expect(isValidIndexedOffset(255));
    try testing.expect(isValidIndexedOffset(-256));
}

test "isValidIndexedOffset: out of range" {
    try testing.expect(!isValidIndexedOffset(256));
    try testing.expect(!isValidIndexedOffset(-257));
}

test "legalizeOffset: valid offset" {
    const result = legalizeOffset(64, 8);
    try testing.expectEqual(@as(@TypeOf(result), .valid), result);
}

test "legalizeOffset: requires split" {
    const result = legalizeOffset(40000, 8);
    try testing.expect(result == .split_offset or result == .materialize_base);
}

test "condSelectStrategy: all integer conditions native" {
    const result = condSelectStrategy(.eq);
    try testing.expect(result == .native);

    const result2 = condSelectStrategy(.slt);
    try testing.expect(result2 == .native);
}

test "floatCondSelectStrategy: ordered native" {
    const result = floatCondSelectStrategy(.eq);
    try testing.expect(result == .native);
}

test "floatCondSelectStrategy: unordered requires expansion" {
    const result = floatCondSelectStrategy(.ueq);
    try testing.expectEqual(CondSelectExpansion.expand, result);
}

test "checkVectorElementSize: supported sizes" {
    try testing.expectEqual(VectorLegalization.supported, checkVectorElementSize(Type.I8X16));
    try testing.expectEqual(VectorLegalization.supported, checkVectorElementSize(Type.I16X8));
    try testing.expectEqual(VectorLegalization.supported, checkVectorElementSize(Type.I32X4));
    try testing.expectEqual(VectorLegalization.supported, checkVectorElementSize(Type.I64X2));
}

test "checkVectorElementSize: scalar types supported" {
    try testing.expectEqual(VectorLegalization.supported, checkVectorElementSize(Type.I32));
    try testing.expectEqual(VectorLegalization.supported, checkVectorElementSize(Type.F64));
}

test "requiresVectorLegalization: standard vectors" {
    try testing.expect(!requiresVectorLegalization(Type.I32X4));
    try testing.expect(!requiresVectorLegalization(Type.F32X4));
}
