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

/// Convert IntCC to aarch64 CondCode.
/// Maps IR condition codes to ARM condition codes.
pub fn intccToCondCode(cc: root.condcodes.IntCC) root.aarch64_inst.CondCode {
    return switch (cc) {
        .eq => .eq,
        .ne => .ne,
        .slt => .lt,
        .sge => .ge,
        .sgt => .gt,
        .sle => .le,
        .ult => .lo,
        .uge => .hs,
        .ugt => .hi,
        .ule => .ls,
    };
}

/// Constructor: Create CMP instruction (register, register).
/// CMP is an alias for SUBS with XZR as destination.
pub fn aarch64_cmp_rr(ty: root.types.Type, x: lower_mod.Value, y: lower_mod.Value, cc: root.condcodes.IntCC, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToOperandSize(ty);
    const reg_x = try getValueReg(ctx, x);
    const reg_y = try getValueReg(ctx, y);
    _ = cc; // Condition code stored separately for branch
    return Inst{ .cmp_rr = .{
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
}

/// Constructor: Create CMP instruction (register, immediate).
/// CMP is an alias for SUBS with XZR as destination.
pub fn aarch64_cmp_imm(ty: root.types.Type, x: lower_mod.Value, imm: i64, cc: root.condcodes.IntCC, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToOperandSize(ty);
    const reg_x = try getValueReg(ctx, x);
    _ = cc; // Condition code stored separately for branch
    return Inst{ .cmp_imm = .{
        .src = reg_x,
        .imm = @intCast(imm),
        .size = size,
    } };
}

/// Constructor: Create CMN instruction (register, register).
/// CMN is an alias for ADDS with XZR as destination.
pub fn aarch64_cmn_rr(ty: root.types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToOperandSize(ty);
    const reg_x = try getValueReg(ctx, x);
    const reg_y = try getValueReg(ctx, y);
    return Inst{ .cmn_rr = .{
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
}

/// Constructor: Create CMN instruction (register, immediate).
/// CMN is an alias for ADDS with XZR as destination.
pub fn aarch64_cmn_imm(ty: root.types.Type, x: lower_mod.Value, imm: i64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToOperandSize(ty);
    const reg_x = try getValueReg(ctx, x);
    return Inst{ .cmn_imm = .{
        .src = reg_x,
        .imm = @intCast(imm),
        .size = size,
    } };
}

/// Constructor: Create TST instruction (register, register).
/// TST is an alias for ANDS with XZR as destination.
pub fn aarch64_tst_rr(ty: root.types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToOperandSize(ty);
    const reg_x = try getValueReg(ctx, x);
    const reg_y = try getValueReg(ctx, y);
    return Inst{ .tst_rr = .{
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
}

/// Constructor: Create TST instruction (register, immediate).
/// TST is an alias for ANDS with XZR as destination.
pub fn aarch64_tst_imm(ty: root.types.Type, x: lower_mod.Value, imm: u64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToOperandSize(ty);
    const reg_x = try getValueReg(ctx, x);
    const imm_logic = ImmLogic.maybeFromU64(imm, size) orelse return error.InvalidLogicalImmediate;
    return Inst{ .tst_imm = .{
        .src = reg_x,
        .imm = imm_logic,
        .size = size,
    } };
}

/// Constructor: Sign-extend byte (SXTB).
pub fn aarch64_sxtb(dst_ty: root.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const dst_size = typeToOperandSize(dst_ty);
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .sxtb = .{
        .dst = ctx.newTempReg(.int),
        .src = src_reg,
        .dst_size = dst_size,
    } };
}

/// Constructor: Zero-extend byte (UXTB).
pub fn aarch64_uxtb(dst_ty: root.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const dst_size = typeToOperandSize(dst_ty);
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .uxtb = .{
        .dst = ctx.newTempReg(.int),
        .src = src_reg,
        .dst_size = dst_size,
    } };
}

/// Constructor: Sign-extend halfword (SXTH).
pub fn aarch64_sxth(dst_ty: root.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const dst_size = typeToOperandSize(dst_ty);
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .sxth = .{
        .dst = ctx.newTempReg(.int),
        .src = src_reg,
        .dst_size = dst_size,
    } };
}

/// Constructor: Zero-extend halfword (UXTH).
pub fn aarch64_uxth(dst_ty: root.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const dst_size = typeToOperandSize(dst_ty);
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .uxth = .{
        .dst = ctx.newTempReg(.int),
        .src = src_reg,
        .dst_size = dst_size,
    } };
}

/// Constructor: Sign-extend word (SXTW).
pub fn aarch64_sxtw(src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .sxtw = .{
        .dst = ctx.newTempReg(.int),
        .src = src_reg,
    } };
}

/// Constructor: Zero-extend word (UXTW).
/// Note: In ARM64, 32-bit operations zero-extend automatically.
pub fn aarch64_uxtw(src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .uxtw = .{
        .dst = ctx.newTempReg(.int),
        .src = src_reg,
    } };
}

/// Constructor: Integer reduce (truncate to narrower type).
/// On ARM64, this is just a register move with the target size.
/// I64 -> I32: move to W register (implicit truncation)
/// I64 -> I16/I8: move to W register, then truncate with mask
pub fn aarch64_ireduce(dst_ty: root.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const dst_size = typeToOperandSize(dst_ty);
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .mov_rr = .{
        .dst = ctx.newTempReg(.int),
        .src = src_reg,
        .size = dst_size,
    } };
}

/// Constructor: Convert signed integer to float (SCVTF).
pub fn aarch64_scvtf(dst_ty: root.types.Type, src_ty: root.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_size = typeToOperandSize(src_ty);
    const dst_size = typeToFpuOperandSize(dst_ty);
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .scvtf = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
        .src_size = src_size,
        .dst_size = dst_size,
    } };
}

/// Constructor: Convert unsigned integer to float (UCVTF).
pub fn aarch64_ucvtf(dst_ty: root.types.Type, src_ty: root.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_size = typeToOperandSize(src_ty);
    const dst_size = typeToFpuOperandSize(dst_ty);
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .ucvtf = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
        .src_size = src_size,
        .dst_size = dst_size,
    } };
}

/// Constructor: Float promote f32 to f64 (FCVT).
pub fn aarch64_fpromote(src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueRegFloat(ctx, src);
    return Inst{ .fcvt_f32_to_f64 = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
    } };
}

/// Constructor: Float demote f64 to f32 (FCVT).
pub fn aarch64_fdemote(src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueRegFloat(ctx, src);
    return Inst{ .fcvt_f64_to_f32 = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
    } };
}

/// Constructor: Float round to nearest (FRINTN).
pub fn aarch64_nearest(ty: root.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToFpuOperandSize(ty);
    const src_reg = try getValueRegFloat(ctx, src);
    return Inst{ .frintn = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
        .size = size,
    } };
}

/// Constructor: Float round toward zero (FRINTZ).
pub fn aarch64_trunc(ty: root.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToFpuOperandSize(ty);
    const src_reg = try getValueRegFloat(ctx, src);
    return Inst{ .frintz = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
        .size = size,
    } };
}

/// Constructor: Float round toward +infinity (FRINTP).
pub fn aarch64_ceil(ty: root.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToFpuOperandSize(ty);
    const src_reg = try getValueRegFloat(ctx, src);
    return Inst{ .frintp = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
        .size = size,
    } };
}

/// Constructor: Float round toward -infinity (FRINTM).
pub fn aarch64_floor(ty: root.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToFpuOperandSize(ty);
    const src_reg = try getValueRegFloat(ctx, src);
    return Inst{ .frintm = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
        .size = size,
    } };
}

/// Constructor: Create ValueRegs from two I64 values (for iconcat).
/// Takes low and high 64-bit values, returns a ValueRegs pair for I128.
pub fn value_regs_from_values(lo: lower_mod.Value, hi: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs(lower_mod.VReg) {
    // Get VRegs for each value (both must be I64, so single-reg)
    const lo_vregs = try ctx.getValueRegs(lo, .int);
    const hi_vregs = try ctx.getValueRegs(hi, .int);

    // Extract single VRegs (lo and hi must be 64-bit or smaller)
    const lo_vreg = switch (lo_vregs) {
        .one => |r| r,
        .two => return error.InvalidIconcatOperand, // I64 should never be two regs
    };
    const hi_vreg = switch (hi_vregs) {
        .one => |r| r,
        .two => return error.InvalidIconcatOperand,
    };

    // Return pair representing I128
    return lower_mod.ValueRegs(lower_mod.VReg).two(lo_vreg, hi_vreg);
}

/// Constructor: Atomic load with acquire semantics (LDAR).
pub fn aarch64_atomic_load_acquire(ty: root.types.Type, addr: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const addr_reg = try getValueReg(ctx, addr);
    const size = typeToOperandSize(ty);

    if (size == .size64) {
        return Inst{ .ldar = .{
            .dst = ctx.newTempReg(.int),
            .addr = addr_reg,
        } };
    } else {
        return Inst{ .ldar_w = .{
            .dst = ctx.newTempReg(.int),
            .addr = addr_reg,
        } };
    }
}

/// Constructor: Atomic store with release semantics (STLR).
pub fn aarch64_atomic_store_release(ty: root.types.Type, addr: lower_mod.Value, val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const addr_reg = try getValueReg(ctx, addr);
    const val_reg = try getValueReg(ctx, val);
    const size = typeToOperandSize(ty);

    if (size == .size64) {
        return Inst{ .stlr = .{
            .src = val_reg,
            .addr = addr_reg,
        } };
    } else {
        return Inst{ .stlr_w = .{
            .src = val_reg,
            .addr = addr_reg,
        } };
    }
}

/// Constructor: Memory fence (DMB).
pub fn aarch64_fence(ordering: root.atomics.AtomicOrdering) !Inst {
    const barrier = switch (ordering) {
        .seq_cst => root.aarch64_inst.BarrierOp.ish,      // Sequential consistency: full barrier
        .release => root.aarch64_inst.BarrierOp.ishst,    // Release: store barrier
        .acquire => root.aarch64_inst.BarrierOp.ishld,    // Acquire: load barrier
        .acq_rel => root.aarch64_inst.BarrierOp.ish,      // Acquire-release: full barrier
        else => return error.UnsupportedAtomicOrdering,
    };

    return Inst{ .dmb = .{ .option = barrier } };
}

/// Helper: Convert IR type to aarch64 operand size.
fn typeToOperandSize(ty: root.types.Type) root.aarch64_inst.OperandSize {
    if (ty.bits() <= 32) {
        return .size32;
    } else {
        return .size64;
    }
}

/// Helper: Convert IR type to aarch64 FPU operand size.
fn typeToFpuOperandSize(ty: root.types.Type) root.aarch64_inst.FpuOperandSize {
    if (ty.bits() <= 32) {
        return .size32;
    } else if (ty.bits() <= 64) {
        return .size64;
    } else {
        return .size128;
    }
}

/// Helper: Get register for IR value.
fn getValueReg(ctx: *lower_mod.LowerCtx(Inst), value: lower_mod.Value) !lower_mod.Reg {
    const vreg = try ctx.getValueReg(value, .int);
    return lower_mod.Reg.fromVReg(vreg);
}

/// Helper: Get FP register for IR value.
fn getValueRegFloat(ctx: *lower_mod.LowerCtx(Inst), value: lower_mod.Value) !lower_mod.Reg {
    const vreg = try ctx.getValueReg(value, .float);
    return lower_mod.Reg.fromVReg(vreg);
}

/// Constructor: Convert F32 to I32 with saturation (FCVTZS).
pub fn aarch64_fcvtzs_32_to_32(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const val_reg = try getValueRegFloat(ctx, val);
    return Inst{ .fcvtzs = .{
        .dst = ctx.newTempReg(.int),
        .src = val_reg,
        .src_size = .size32,
        .dst_size = .size32,
    } };
}

/// Constructor: Convert F64 to I32 with saturation (FCVTZS).
pub fn aarch64_fcvtzs_64_to_32(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const val_reg = try getValueRegFloat(ctx, val);
    return Inst{ .fcvtzs = .{
        .dst = ctx.newTempReg(.int),
        .src = val_reg,
        .src_size = .size64,
        .dst_size = .size32,
    } };
}

/// Constructor: Convert F32 to I64 with saturation (FCVTZS).
pub fn aarch64_fcvtzs_32_to_64(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const val_reg = try getValueRegFloat(ctx, val);
    return Inst{ .fcvtzs = .{
        .dst = ctx.newTempReg(.int),
        .src = val_reg,
        .src_size = .size32,
        .dst_size = .size64,
    } };
}

/// Constructor: Convert F64 to I64 with saturation (FCVTZS).
pub fn aarch64_fcvtzs_64_to_64(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const val_reg = try getValueRegFloat(ctx, val);
    return Inst{ .fcvtzs = .{
        .dst = ctx.newTempReg(.int),
        .src = val_reg,
        .src_size = .size64,
        .dst_size = .size64,
    } };
}

/// Constructor: Convert F32 to U32 with saturation (FCVTZU).
pub fn aarch64_fcvtzu_32_to_32(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const val_reg = try getValueRegFloat(ctx, val);
    return Inst{ .fcvtzu = .{
        .dst = ctx.newTempReg(.int),
        .src = val_reg,
        .src_size = .size32,
        .dst_size = .size32,
    } };
}

/// Constructor: Convert F64 to U32 with saturation (FCVTZU).
pub fn aarch64_fcvtzu_64_to_32(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const val_reg = try getValueRegFloat(ctx, val);
    return Inst{ .fcvtzu = .{
        .dst = ctx.newTempReg(.int),
        .src = val_reg,
        .src_size = .size64,
        .dst_size = .size32,
    } };
}

/// Constructor: Convert F32 to U64 with saturation (FCVTZU).
pub fn aarch64_fcvtzu_32_to_64(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const val_reg = try getValueRegFloat(ctx, val);
    return Inst{ .fcvtzu = .{
        .dst = ctx.newTempReg(.int),
        .src = val_reg,
        .src_size = .size32,
        .dst_size = .size64,
    } };
}

/// Constructor: Convert F64 to U64 with saturation (FCVTZU).
pub fn aarch64_fcvtzu_64_to_64(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const val_reg = try getValueRegFloat(ctx, val);
    return Inst{ .fcvtzu = .{
        .dst = ctx.newTempReg(.int),
        .src = val_reg,
        .src_size = .size64,
        .dst_size = .size64,
    } };
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

test "intccToCondCode: equality conditions" {
    const testing = std.testing;

    try testing.expectEqual(root.aarch64_inst.CondCode.eq, intccToCondCode(.eq));
    try testing.expectEqual(root.aarch64_inst.CondCode.ne, intccToCondCode(.ne));
}

test "intccToCondCode: signed conditions" {
    const testing = std.testing;

    try testing.expectEqual(root.aarch64_inst.CondCode.lt, intccToCondCode(.slt));
    try testing.expectEqual(root.aarch64_inst.CondCode.ge, intccToCondCode(.sge));
    try testing.expectEqual(root.aarch64_inst.CondCode.gt, intccToCondCode(.sgt));
    try testing.expectEqual(root.aarch64_inst.CondCode.le, intccToCondCode(.sle));
}

test "intccToCondCode: unsigned conditions" {
    const testing = std.testing;

    try testing.expectEqual(root.aarch64_inst.CondCode.lo, intccToCondCode(.ult));
    try testing.expectEqual(root.aarch64_inst.CondCode.hs, intccToCondCode(.uge));
    try testing.expectEqual(root.aarch64_inst.CondCode.hi, intccToCondCode(.ugt));
    try testing.expectEqual(root.aarch64_inst.CondCode.ls, intccToCondCode(.ule));
}

test "aarch64_cmp_rr: creates compare instruction" {
    const testing = std.testing;

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const v1 = lower_mod.Value.new(0);
    const v2 = lower_mod.Value.new(1);

    const inst = try aarch64_cmp_rr(root.types.Type.I64, v1, v2, .eq, &ctx);

    try testing.expectEqual(Inst.cmp_rr, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(root.aarch64_inst.OperandSize.size64, inst.cmp_rr.size);
}

test "aarch64_cmp_imm: creates compare immediate instruction" {
    const testing = std.testing;

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const v1 = lower_mod.Value.new(0);

    const inst = try aarch64_cmp_imm(root.types.Type.I32, v1, 42, .ne, &ctx);

    try testing.expectEqual(Inst.cmp_imm, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(root.aarch64_inst.OperandSize.size32, inst.cmp_imm.size);
    try testing.expectEqual(@as(u16, 42), inst.cmp_imm.imm);
}

test "aarch64_cmn_rr: creates compare negative instruction" {
    const testing = std.testing;

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const v1 = lower_mod.Value.new(0);
    const v2 = lower_mod.Value.new(1);

    const inst = try aarch64_cmn_rr(root.types.Type.I64, v1, v2, &ctx);

    try testing.expectEqual(Inst.cmn_rr, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(root.aarch64_inst.OperandSize.size64, inst.cmn_rr.size);
}

test "aarch64_cmn_imm: creates compare negative immediate instruction" {
    const testing = std.testing;

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const v1 = lower_mod.Value.new(0);

    const inst = try aarch64_cmn_imm(root.types.Type.I32, v1, 100, &ctx);

    try testing.expectEqual(Inst.cmn_imm, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(root.aarch64_inst.OperandSize.size32, inst.cmn_imm.size);
    try testing.expectEqual(@as(u16, 100), inst.cmn_imm.imm);
}

test "aarch64_tst_rr: creates test bits instruction" {
    const testing = std.testing;

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const v1 = lower_mod.Value.new(0);
    const v2 = lower_mod.Value.new(1);

    const inst = try aarch64_tst_rr(root.types.Type.I64, v1, v2, &ctx);

    try testing.expectEqual(Inst.tst_rr, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(root.aarch64_inst.OperandSize.size64, inst.tst_rr.size);
}

test "aarch64_tst_imm: creates test bits immediate instruction" {
    const testing = std.testing;

    var func = lower_mod.Function.init(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const v1 = lower_mod.Value.new(0);

    const inst = try aarch64_tst_imm(root.types.Type.I64, v1, 0xFF, &ctx);

    try testing.expectEqual(Inst.tst_imm, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(root.aarch64_inst.OperandSize.size64, inst.tst_imm.imm.size);
}

/// Constructor: SSHLL - Signed shift-left-long (widen and shift).
/// Widens lower or upper half of vector elements and optionally shifts left.
pub fn aarch64_sshll(val: lower_mod.Value, output_size: Inst.VecElemSize, shift_amt: u8, high: bool, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, val);

    return Inst{ .vec_sshll = .{
        .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
        .src = src_reg,
        .shift_amt = shift_amt,
        .size = output_size,
        .high = high,
    } };
}

/// Constructor: USHLL - Unsigned shift-left-long (widen and shift).
/// Widens lower or upper half of vector elements and optionally shifts left.
pub fn aarch64_ushll(val: lower_mod.Value, output_size: Inst.VecElemSize, shift_amt: u8, high: bool, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, val);

    return Inst{ .vec_ushll = .{
        .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
        .src = src_reg,
        .shift_amt = shift_amt,
        .size = output_size,
        .high = high,
    } };
}

/// Constructor: Combined SQXTN + SQXTN2 - Signed saturating narrow.
/// Narrows x to low half and y to high half of output vector.
pub fn aarch64_sqxtn_combined(x: lower_mod.Value, y: lower_mod.Value, output_size: Inst.VecElemSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    // First narrow x to low half
    const temp_reg = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    const low_inst = Inst{ .vec_sqxtn = .{
        .dst = temp_reg,
        .src = x_reg,
        .size = output_size,
        .high = false,
    } };
    try ctx.emit(low_inst);

    // Then narrow y to high half (writes to same register)
    return Inst{ .vec_sqxtn = .{
        .dst = temp_reg,
        .src = y_reg,
        .size = output_size,
        .high = true,
    } };
}

/// Constructor: Combined SQXTUN + SQXTUN2 - Signed to unsigned saturating narrow.
pub fn aarch64_sqxtun_combined(x: lower_mod.Value, y: lower_mod.Value, output_size: Inst.VecElemSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    const temp_reg = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    const low_inst = Inst{ .vec_sqxtun = .{
        .dst = temp_reg,
        .src = x_reg,
        .size = output_size,
        .high = false,
    } };
    try ctx.emit(low_inst);

    return Inst{ .vec_sqxtun = .{
        .dst = temp_reg,
        .src = y_reg,
        .size = output_size,
        .high = true,
    } };
}

/// Constructor: Combined UQXTN + UQXTN2 - Unsigned saturating narrow.
pub fn aarch64_uqxtn_combined(x: lower_mod.Value, y: lower_mod.Value, output_size: Inst.VecElemSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    const temp_reg = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    const low_inst = Inst{ .vec_uqxtn = .{
        .dst = temp_reg,
        .src = x_reg,
        .size = output_size,
        .high = false,
    } };
    try ctx.emit(low_inst);

    return Inst{ .vec_uqxtn = .{
        .dst = temp_reg,
        .src = y_reg,
        .size = output_size,
        .high = true,
    } };
}

/// FCVTL - Float convert to higher precision (F32 -> F64)
/// Converts F32X4 to F64X2 (promotes low or high 2 lanes)
pub fn aarch64_fcvtl(val: lower_mod.Value, high: bool, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, val);

    return Inst{ .vec_fcvtl = .{
        .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
        .src = src_reg,
        .high = high,
    } };
}

/// FCVTN - Float convert to lower precision (F64 -> F32) - combined variant
/// Converts two F64X2 vectors to one F32X4 vector
/// Emits FCVTN (low half) then FCVTN2 (high half)
pub fn aarch64_fcvtn_combined(x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    // First demote x to low half
    const temp_reg = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    const low_inst = Inst{ .vec_fcvtn = .{
        .dst = temp_reg,
        .src = x_reg,
        .high = false,
    } };
    try ctx.emit(low_inst);

    // Then demote y to high half
    return Inst{ .vec_fcvtn = .{
        .dst = temp_reg,
        .src = y_reg,
        .high = true,
    } };
}
