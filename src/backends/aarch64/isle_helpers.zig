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
    const const_val = intValue(value, ctx) orelse return null;
    const negated = -%const_val;
    if (negated < 0 or negated > 4095) return null;
    return Imm12.maybeFromU64(@intCast(negated));
}

/// Helper: Extract integer constant value from an iconst instruction.
/// Returns null if the value is not defined by iconst or if immediate data is not available.
fn intValue(value: lower_mod.Value, ctx: *const lower_mod.LowerCtx(Inst)) ?i64 {
    // TODO: LowerCtx needs access to IR DFG to query instruction data
    // Once LowerCtx.func provides DFG access, implement as:
    //   const def = ctx.func.dfg.valueDef(value);
    //   if (def.inst) |inst| {
    //       const inst_data = ctx.func.dfg.insts.get(inst) orelse return null;
    //       if (inst_data.* == .nullary and inst_data.nullary.opcode == .iconst) {
    //           return ctx.func.dfg.iconst_pool.get(inst); // requires immediate pool
    //       }
    //   }
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
    // Get the value definition
    const def = ctx.func.dfg.valueDef(value) orelse return null;

    // Get the instruction that defines this value
    const inst = def.inst() orelse return null;

    // Get instruction data
    const inst_data = ctx.func.dfg.insts.get(inst) orelse return null;

    // Check if this is an extending load operation
    const extend_op: ExtendOp = switch (inst_data.opcode()) {
        .sload8 => .sxtb, // Sign-extend byte
        .sload16 => .sxth, // Sign-extend halfword
        .sload32 => .sxtw, // Sign-extend word
        .uload8 => .uxtb, // Zero-extend byte
        .uload16 => .uxth, // Zero-extend halfword
        .uload32 => .uxtw, // Zero-extend word
        else => return null,
    };

    // Get or allocate register for this value
    const vreg = ctx.value_to_reg.get(value) orelse return null;
    const reg = lower_mod.Reg.fromVReg(vreg);

    return ExtendedValue{
        .reg = reg,
        .op = extend_op,
    };
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
