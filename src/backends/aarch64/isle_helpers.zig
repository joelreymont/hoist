/// ISLE extractor and constructor helpers for aarch64.
/// These functions are called from ISLE-generated code via extern declarations.
const std = @import("std");
const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const Imm12 = root.aarch64_inst.Imm12;
const ImmShift = root.aarch64_inst.ImmShift;
const ImmLogic = root.aarch64_inst.ImmLogic;
const ExtendOp = root.aarch64_inst.ExtendOp;
const lower_mod = root.lower;
const types = root.types;

/// Extractor: Try to extract Imm12 from u64.
/// Returns the Imm12 if the value fits, null otherwise.
pub fn imm12_from_u64(val: u64) ?Imm12 {
    return Imm12.maybeFromU64(val);
}

/// Extractor: Try to extract Imm12 from negated Value.
/// Returns the Imm12 if -value fits in 12-bit encoding.
pub fn imm12_from_negated_value(value: lower_mod.Value, ctx: *const lower_mod.LowerCtx(Inst)) ?Imm12 {
    // TODO: Need access to IR data to get iconst value
    // This requires extending LowerCtx with value query methods
    _ = value;
    _ = ctx;
    return null;
}

/// Constructor: Convert Imm12 back to u64.
pub fn u64_from_imm12(imm: Imm12) u64 {
    return imm.toU64();
}

/// Constructor: Convert u8 to Imm12 (always succeeds for u8).
pub fn u8_into_imm12(val: u8) Imm12 {
    return .{ .bits = val, .shift12 = false };
}

/// Extractor: Try to extract ImmShift from u64.
pub fn imm_shift_from_u64(val: u64) ?ImmShift {
    return ImmShift.maybeFromU64(val);
}

/// Constructor: Convert u8 to ImmShift (must be < 64).
pub fn imm_shift_from_u8(val: u8) ?ImmShift {
    return ImmShift.maybeFromU64(val);
}

/// Constructor: Create ImmLogic from u64 for given type.
pub fn imm_logic_from_u64(ty: types.Type, val: u64) ?ImmLogic {
    const size = if (ty.bits() <= 32) .size32 else .size64;
    return ImmLogic.maybeFromU64(val, size);
}

/// ExtendedValue: Represents a value with an extend operation.
/// This is a helper type for patterns like (sxtw (load ...)).
pub const ExtendedValue = struct {
    reg: lower_mod.Reg,
    op: ExtendOp,
};

/// Extractor: Try to extract ExtendedValue from a Value.
/// Looks for patterns like sext/zext applied to narrower loads.
pub fn extended_value_from_value(value: lower_mod.Value, ctx: *const lower_mod.LowerCtx(Inst)) ?ExtendedValue {
    // TODO: Need IR instruction analysis to detect extend patterns
    // This requires access to instruction def-use chains
    _ = value;
    _ = ctx;
    return null;
}

/// Constructor: Get the register from an ExtendedValue.
pub fn put_extended_in_reg(ev: ExtendedValue) lower_mod.Reg {
    return ev.reg;
}

/// Constructor: Get the extend operation from an ExtendedValue.
pub fn get_extended_op(ev: ExtendedValue) ExtendOp {
    return ev.op;
}

/// Helper function: Negate an i64 value.
/// Used for isub -> iadd optimization with negated immediates.
pub fn negate_i64(val: i64) i64 {
    return -%val;
}

/// Extractor: Check if value is in range where negation fits in unsigned 12-bit.
/// Returns true if -4095 <= val <= -1 (i.e., -val fits in 0-4095).
pub fn in_neg_uimm12_range(val: i64) bool {
    return val >= -4095 and val <= -1;
}

test "imm12_from_u64" {
    const testing = std.testing;

    // Valid 12-bit immediate
    const imm1 = imm12_from_u64(100).?;
    try testing.expectEqual(@as(u16, 100), imm1.bits);
    try testing.expectEqual(false, imm1.shift12);

    // Valid shifted immediate
    const imm2 = imm12_from_u64(0x1000).?;
    try testing.expectEqual(@as(u16, 1), imm2.bits);
    try testing.expectEqual(true, imm2.shift12);

    // Invalid - too large
    try testing.expectEqual(@as(?Imm12, null), imm12_from_u64(0x10000));
}

test "imm_shift_from_u64" {
    const testing = std.testing;

    const sh1 = imm_shift_from_u64(32).?;
    try testing.expectEqual(@as(u8, 32), sh1.imm);

    try testing.expectEqual(@as(?ImmShift, null), imm_shift_from_u64(64));
}

test "u8_into_imm12" {
    const testing = std.testing;

    const imm = u8_into_imm12(255);
    try testing.expectEqual(@as(u16, 255), imm.bits);
    try testing.expectEqual(false, imm.shift12);
}
