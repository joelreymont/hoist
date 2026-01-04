/// ISLE extractor and constructor helpers for aarch64.
/// These functions are called from ISLE-generated code via extern declarations.
const std = @import("std");
const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const Reg = root.aarch64_inst.Reg;
const Imm12 = root.aarch64_inst.Imm12;
const ImmShift = root.aarch64_inst.ImmShift;
const ImmLogic = root.aarch64_inst.ImmLogic;
const ExtendOp = root.aarch64_inst.ExtendOp;
const lower_mod = root.lower;
const types = root.types;
const trapcode = root.trapcode;
const emit = @import("emit.zig");
const entities = root.entities;

// Type aliases for IR types
const TrapCode = trapcode.TrapCode;
const StackSlot = entities.StackSlot;
const SigRef = entities.SigRef;
const ExternalName = entities.ExternalName;
const VectorSize = enum {
    V8B,
    V16B,
    V4H,
    V8H,
    V2S,
    V4S,
    V2D,
};

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

/// Extractor: Check if value fits in unsigned 12-bit (0-4095).
/// Returns the value if valid, null otherwise.
pub fn uimm12(val: u64) ?u64 {
    if (val <= 4095) return val;
    return null;
}

/// Extractor: Check if value fits in unsigned 16-bit (0-65535).
/// Returns the value if valid, null otherwise.
pub fn uimm16(val: u64) ?u64 {
    if (val <= 65535) return val;
    return null;
}

/// Extractor: Check if value is a valid shift amount (0-63).
/// Returns the value if valid, null otherwise.
pub fn valid_shift_imm(val: u64) ?u64 {
    if (val <= 63) return val;
    return null;
}

/// Extractor: Extract rotl immediate and convert to rotr immediate.
/// ARM64 has ROR but not ROL, so rotl(x, k) = rotr(x, width - k).
/// Returns the rotr shift amount if valid, null otherwise.
pub fn valid_rotl_imm(width: u32, k: u64) ?u32 {
    if (k > 63) return null;
    const k32: u32 = @intCast(k);
    if (k32 >= width) return null;
    return width - k32;
}

/// Extractor: Check if offset is valid for load immediate addressing.
/// Accepts offsets 0-32760 (max for I64 8-byte aligned access).
/// Returns the offset if valid, null otherwise.
pub fn valid_ldr_imm_offset(ty: types.Type, offset: u64) ?u64 {
    _ = ty; // Type used for alignment checking in full implementation
    if (offset <= 32760) return offset;
    return null;
}

/// Extractor: Check if offset is valid for store immediate addressing.
/// Returns the offset if valid, null otherwise.
pub fn valid_str_imm_offset(val: lower_mod.Value, offset: u64) ?u64 {
    _ = val; // Value type used for alignment checking in full implementation
    if (offset <= 32760) return offset;
    return null;
}

/// Extractor: Check if shift is valid for load (must be 0-3).
/// Returns the shift if valid, null otherwise.
pub fn valid_ldr_shift(ty: types.Type, shift: u64) ?u64 {
    _ = ty; // Type determines valid shift range
    if (shift <= 3) return shift;
    return null;
}

/// Extractor: Check if shift is valid for store (must be 0-3).
/// Returns the shift if valid, null otherwise.
pub fn valid_str_shift(val: lower_mod.Value, shift: u64) ?u64 {
    _ = val; // Value type determines valid shift range
    if (shift <= 3) return shift;
    return null;
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
        .seq_cst => root.aarch64_inst.BarrierOp.ish, // Sequential consistency: full barrier
        .release => root.aarch64_inst.BarrierOp.ishst, // Release: store barrier
        .acquire => root.aarch64_inst.BarrierOp.ishld, // Acquire: load barrier
        .acq_rel => root.aarch64_inst.BarrierOp.ish, // Acquire-release: full barrier
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

/// CLZ - Count leading zeros (32-bit)
pub fn aarch64_clz_32(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, val);

    return Inst{ .clz = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = src_reg,
        .size = .size32,
    } };
}

/// CLZ - Count leading zeros (64-bit)
pub fn aarch64_clz_64(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, val);

    return Inst{ .clz = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = src_reg,
        .size = .size64,
    } };
}

/// CTZ - Count trailing zeros (32-bit)
/// ARM64 doesn't have CTZ, so we emit RBIT + CLZ
pub fn aarch64_ctz_32(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, val);

    // First reverse bits
    const rbit_dst = lower_mod.WritableVReg.allocVReg(.int, ctx);
    const rbit_inst = Inst{ .rbit = .{
        .dst = rbit_dst,
        .src = src_reg,
        .size = .size32,
    } };
    try ctx.emit(rbit_inst);

    // Then count leading zeros
    return Inst{ .clz = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = rbit_dst.toReg(),
        .size = .size32,
    } };
}

/// CTZ - Count trailing zeros (64-bit)
pub fn aarch64_ctz_64(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, val);

    // First reverse bits
    const rbit_dst = lower_mod.WritableVReg.allocVReg(.int, ctx);
    const rbit_inst = Inst{ .rbit = .{
        .dst = rbit_dst,
        .src = src_reg,
        .size = .size64,
    } };
    try ctx.emit(rbit_inst);

    // Then count leading zeros
    return Inst{ .clz = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = rbit_dst.toReg(),
        .size = .size64,
    } };
}

/// RBIT - Reverse bits (32-bit)
pub fn aarch64_rbit_32(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, val);

    return Inst{ .rbit = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = src_reg,
        .size = .size32,
    } };
}

/// RBIT - Reverse bits (64-bit)
pub fn aarch64_rbit_64(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, val);

    return Inst{ .rbit = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = src_reg,
        .size = .size64,
    } };
}

/// BSWAP - Byte swap (16-bit)
/// Uses REV16 instruction
pub fn aarch64_bswap_16(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, val);

    return Inst{
        .rev16 = .{
            .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
            .src = src_reg,
            .size = .size32, // REV16 operates on 32-bit register
        },
    };
}

/// BSWAP - Byte swap (32-bit)
/// Uses REV32 instruction (or REV for 32-bit)
pub fn aarch64_bswap_32(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, val);

    return Inst{ .rev32 = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = src_reg,
        .size = .size32,
    } };
}

/// BSWAP - Byte swap (64-bit)
/// Uses REV64 instruction
pub fn aarch64_bswap_64(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueReg(ctx, val);

    return Inst{ .rev64 = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = src_reg,
    } };
}

/// FADD - Floating-point addition
pub fn aarch64_fadd(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    if (ty == types.Type.F32) {
        return Inst{ .fadd_s = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
        } };
    } else { // F64
        return Inst{ .fadd_d = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
        } };
    }
}

/// FSUB - Floating-point subtraction
pub fn aarch64_fsub(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    if (ty == types.Type.F32) {
        return Inst{ .fsub_s = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
        } };
    } else { // F64
        return Inst{ .fsub_d = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
        } };
    }
}

/// FMUL - Floating-point multiplication
pub fn aarch64_fmul(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    if (ty == types.Type.F32) {
        return Inst{ .fmul_s = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
        } };
    } else { // F64
        return Inst{ .fmul_d = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
        } };
    }
}

/// FDIV - Floating-point division
pub fn aarch64_fdiv(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    if (ty == types.Type.F32) {
        return Inst{ .fdiv_s = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
        } };
    } else { // F64
        return Inst{ .fdiv_d = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
        } };
    }
}

/// FMIN - Floating-point minimum
pub fn aarch64_fmin(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    if (ty == types.Type.F32) {
        return Inst{ .fmin_s = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
        } };
    } else { // F64
        return Inst{ .fmin_d = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
        } };
    }
}

/// FMAX - Floating-point maximum
pub fn aarch64_fmax(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    if (ty == types.Type.F32) {
        return Inst{ .fmax_s = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
        } };
    } else { // F64
        return Inst{ .fmax_d = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
        } };
    }
}

/// ROTL - Rotate left (register amount)
/// Implemented as rotr(x, -y) since ARM64 only has ROR
pub fn aarch64_rotl_rr(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    const size: Inst.OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

    // Negate the shift amount: neg_y = 0 - y
    const neg_y = lower_mod.WritableVReg.allocVReg(.int, ctx);
    const neg_inst = Inst{ .neg = .{
        .dst = neg_y,
        .src = y_reg,
        .size = size,
    } };
    try ctx.emit(neg_inst);

    // Rotate right by the negated amount: rotr(x, -y) == rotl(x, y)
    return Inst{ .ror_rr = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src1 = x_reg,
        .src2 = neg_y.toReg(),
        .size = size,
    } };
}

/// SPLAT - Duplicate scalar to all vector lanes (DUP)
pub fn aarch64_splat(ty: types.Type, x: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);

    // Determine vector element size from type
    const size: Inst.VecElemSize = switch (ty) {
        types.Type.V8x16 => .size8x16,
        types.Type.V16x8 => .size16x8,
        types.Type.V32x4 => .size32x4,
        types.Type.V64x2 => .size64x2,
        else => return error.UnsupportedType,
    };

    return Inst{ .vec_dup = .{
        .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
        .src = x_reg,
        .size = size,
    } };
}

/// VEC_DUP_FROM_FPU - Duplicate vector element to all lanes (DUP Vd.T, Vn.T[lane])
pub fn vec_dup_from_fpu(src: lower_mod.Value, size_enum: VectorSize, lane: u8, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try ctx.getValueReg(src, .vector);

    // Map ISLE VectorSize enum to VecElemSize
    const size: Inst.VecElemSize = switch (size_enum) {
        .V8B => .size8x8,
        .V16B => .size8x16,
        .V4H => .size16x4,
        .V8H => .size16x8,
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => .size64x2,
    };

    return Inst{ .vec_dup_lane = .{
        .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
        .src = src_reg,
        .lane = lane,
        .size = size,
    } };
}

/// VEC_EXTRACT - Extract bytes and concatenate (EXT Vd, Vn, Vm, #index)
/// Extracts consecutive bytes from concatenated pair: dst = (a:b)[index..index+16]
pub fn vec_extract(a: lower_mod.Value, b: lower_mod.Value, index: u8, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try ctx.getValueReg(a, .vector);
    const b_reg = try ctx.getValueReg(b, .vector);

    return Inst{
        .vec_ext = .{
            .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
            .src1 = a_reg,
            .src2 = b_reg,
            .index = index,
            .size = .size8x16, // EXT always operates on 128-bit vectors
        },
    };
}

/// Map ISLE VectorSize enum to Inst.VecElemSize
fn vectorSizeToElemSize(size_enum: VectorSize) Inst.VecElemSize {
    return switch (size_enum) {
        .V8B => .size8x8,
        .V16B => .size8x16,
        .V4H => .size16x4,
        .V8H => .size16x8,
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => .size64x2,
    };
}

/// VEC_UZP1 - De-interleave even lanes (UZP1 Vd, Vn, Vm)
pub fn vec_uzp1(a: lower_mod.Value, b: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try ctx.getValueReg(a, .vector);
    const b_reg = try ctx.getValueReg(b, .vector);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .uzp1 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src1 = a_reg, .src2 = b_reg, .size = size } };
}

/// VEC_UZP2 - De-interleave odd lanes (UZP2 Vd, Vn, Vm)
pub fn vec_uzp2(a: lower_mod.Value, b: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try ctx.getValueReg(a, .vector);
    const b_reg = try ctx.getValueReg(b, .vector);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .uzp2 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src1 = a_reg, .src2 = b_reg, .size = size } };
}

/// VEC_ZIP1 - Interleave low halves (ZIP1 Vd, Vn, Vm)
pub fn vec_zip1(a: lower_mod.Value, b: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try ctx.getValueReg(a, .vector);
    const b_reg = try ctx.getValueReg(b, .vector);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .zip1 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src1 = a_reg, .src2 = b_reg, .size = size } };
}

/// VEC_ZIP2 - Interleave high halves (ZIP2 Vd, Vn, Vm)
pub fn vec_zip2(a: lower_mod.Value, b: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try ctx.getValueReg(a, .vector);
    const b_reg = try ctx.getValueReg(b, .vector);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .zip2 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src1 = a_reg, .src2 = b_reg, .size = size } };
}

/// VEC_TRN1 - Transpose low halves (TRN1 Vd, Vn, Vm)
pub fn vec_trn1(a: lower_mod.Value, b: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try ctx.getValueReg(a, .vector);
    const b_reg = try ctx.getValueReg(b, .vector);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .trn1 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src1 = a_reg, .src2 = b_reg, .size = size } };
}

/// VEC_TRN2 - Transpose high halves (TRN2 Vd, Vn, Vm)
pub fn vec_trn2(a: lower_mod.Value, b: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try ctx.getValueReg(a, .vector);
    const b_reg = try ctx.getValueReg(b, .vector);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .trn2 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src1 = a_reg, .src2 = b_reg, .size = size } };
}

/// EXTRACTLANE - Extract vector lane to scalar (UMOV)
pub fn aarch64_extractlane(ty: types.Type, vec: lower_mod.Value, lane_val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const vec_reg = try getValueReg(ctx, vec);

    // Extract lane index from constant value
    const lane_node = try ctx.getValue(lane_val);
    const lane: u8 = switch (lane_node) {
        .iconst => |c| @intCast(c.value),
        else => return error.NonConstantLane,
    };

    // Determine vector element size from type
    const size: Inst.VecElemSize = switch (ty) {
        types.Type.V8x16 => .size8x16,
        types.Type.V16x8 => .size16x8,
        types.Type.V32x4 => .size32x4,
        types.Type.V64x2 => .size64x2,
        else => return error.UnsupportedType,
    };

    return Inst{ .vec_extract_lane = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = vec_reg,
        .lane = lane,
        .size = size,
    } };
}

/// SMIN - Signed minimum (CMP + CSEL)
/// Implemented as: cmp x, y; csel result, x, y, lt
pub fn aarch64_smin(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const size: Inst.OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

    // Compare x with y
    const cmp_inst = Inst{ .cmp_rr = .{
        .src1 = x_reg,
        .src2 = y_reg,
        .size = size,
    } };
    try ctx.emit(cmp_inst);

    // Select x if less than, otherwise y
    return Inst{ .csel = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src1 = x_reg,
        .src2 = y_reg,
        .cond = .lt,
        .size = size,
    } };
}

/// UMIN - Unsigned minimum (CMP + CSEL)
/// Implemented as: cmp x, y; csel result, x, y, lo
pub fn aarch64_umin(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const size: Inst.OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

    // Compare x with y
    const cmp_inst = Inst{ .cmp_rr = .{
        .src1 = x_reg,
        .src2 = y_reg,
        .size = size,
    } };
    try ctx.emit(cmp_inst);

    // Select x if unsigned less than, otherwise y
    return Inst{ .csel = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src1 = x_reg,
        .src2 = y_reg,
        .cond = .lo,
        .size = size,
    } };
}

/// SMAX - Signed maximum (CMP + CSEL)
/// Implemented as: cmp x, y; csel result, x, y, gt
pub fn aarch64_smax(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const size: Inst.OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

    // Compare x with y
    const cmp_inst = Inst{ .cmp_rr = .{
        .src1 = x_reg,
        .src2 = y_reg,
        .size = size,
    } };
    try ctx.emit(cmp_inst);

    // Select x if greater than, otherwise y
    return Inst{ .csel = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src1 = x_reg,
        .src2 = y_reg,
        .cond = .gt,
        .size = size,
    } };
}

/// UMAX - Unsigned maximum (CMP + CSEL)
/// Implemented as: cmp x, y; csel result, x, y, hi
pub fn aarch64_umax(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const size: Inst.OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

    // Compare x with y
    const cmp_inst = Inst{ .cmp_rr = .{
        .src1 = x_reg,
        .src2 = y_reg,
        .size = size,
    } };
    try ctx.emit(cmp_inst);

    // Select x if unsigned greater than, otherwise y
    return Inst{ .csel = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src1 = x_reg,
        .src2 = y_reg,
        .cond = .hi,
        .size = size,
    } };
}

/// BITSELECT - Bitwise select: (x & c) | (y & ~c)
/// Implemented as: tmp1 = x & c; tmp2 = y & ~c; result = tmp1 | tmp2
pub fn aarch64_bitselect(c: lower_mod.Value, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const c_reg = try getValueReg(ctx, c);
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    // Get type from one of the values
    const x_node = try ctx.getValue(x);
    const ty = x_node.getType();
    const size: Inst.OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

    // tmp1 = x & c
    const tmp1 = lower_mod.WritableVReg.allocVReg(.int, ctx);
    const and_inst = Inst{ .and_rr = .{
        .dst = tmp1,
        .src1 = x_reg,
        .src2 = c_reg,
        .size = size,
    } };
    try ctx.emit(and_inst);

    // tmp2 = y & ~c (using BIC: y & ~c)
    const tmp2 = lower_mod.WritableVReg.allocVReg(.int, ctx);
    const bic_inst = Inst{ .bic_rr = .{
        .dst = tmp2,
        .src1 = y_reg,
        .src2 = c_reg,
        .size = size,
    } };
    try ctx.emit(bic_inst);

    // result = tmp1 | tmp2
    return Inst{ .orr_rr = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src1 = tmp1.toReg(),
        .src2 = tmp2.toReg(),
        .size = size,
    } };
}

/// FCOPYSIGN (F32) - Copy sign from y to magnitude of x
/// Implemented as: abs_x = fabs(x); neg_abs_x = fneg(abs_x); fcmp y, #0.0; fcsel result, neg_abs_x, abs_x, lt
pub fn aarch64_fcopysign_32(x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const size: Inst.FpuOperandSize = .size32;

    // abs_x = fabs(x)
    const abs_x = lower_mod.WritableVReg.allocVReg(.float, ctx);
    const fabs_inst = Inst{ .fabs = .{
        .dst = abs_x,
        .src = x_reg,
        .size = size,
    } };
    try ctx.emit(fabs_inst);

    // neg_abs_x = fneg(abs_x)
    const neg_abs_x = lower_mod.WritableVReg.allocVReg(.float, ctx);
    const fneg_inst = Inst{ .fneg = .{
        .dst = neg_abs_x,
        .src = abs_x.toReg(),
        .size = size,
    } };
    try ctx.emit(fneg_inst);

    // fcmp y, #0.0
    const fcmp_inst = Inst{ .fcmp_zero = .{
        .src = y_reg,
        .size = size,
    } };
    try ctx.emit(fcmp_inst);

    // fcsel result, neg_abs_x, abs_x, lt  (if y < 0, use neg_abs_x, else abs_x)
    return Inst{ .fcsel = .{
        .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
        .src1 = neg_abs_x.toReg(),
        .src2 = abs_x.toReg(),
        .cond = .lt,
        .size = size,
    } };
}

/// ORR (immediate) - Bitwise OR with logical immediate
pub fn aarch64_orr_imm(ty: types.Type, x: lower_mod.Value, imm: ImmLogic, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const size = typeToOperandSize(ty);
    _ = size; // ImmLogic already encodes size
    return Inst{ .orr_imm = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = x_reg,
        .imm = imm,
    } };
}

/// EOR (immediate) - Bitwise XOR with logical immediate
pub fn aarch64_eor_imm(ty: types.Type, x: lower_mod.Value, imm: ImmLogic, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const size = typeToOperandSize(ty);
    _ = size; // ImmLogic already encodes size
    return Inst{ .eor_imm = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = x_reg,
        .imm = imm,
    } };
}

/// Calculate the minimum floating-point bound for conversion from float to integer.
/// Returns a register containing the minimum representable value minus epsilon.
/// signed: whether the output integer type is signed
/// in_bits: size of input float type (32 or 64)
/// out_bits: size of output integer type (8, 16, 32, or 64)
pub fn min_fp_value(signed: bool, in_bits: u8, out_bits: u8, ctx: *lower_mod.LowerCtx(Inst)) !Reg {
    if (in_bits == 32) {
        // From f32
        const min_f32: f32 = switch (signed) {
            true => switch (out_bits) {
                8 => @as(f32, @floatFromInt(std.math.minInt(i8))) - 1.0,
                16 => @as(f32, @floatFromInt(std.math.minInt(i16))) - 1.0,
                32 => @as(f32, @floatFromInt(std.math.minInt(i32))), // I32_MIN - 1 not precisely representable
                64 => @as(f32, @floatFromInt(std.math.minInt(i64))), // I64_MIN - 1 not precisely representable
                else => unreachable, // Invalid integer size
            },
            false => -1.0, // Unsigned minimum bound
        };

        const bits: u32 = @bitCast(min_f32);
        // Load constant into integer register, then move to FPU
        const int_reg = try ctx.getValueReg(lower_mod.Value.new(0), .int); // Temp allocation
        const load_inst = Inst{ .mov_imm = .{
            .dst = lower_mod.WritableVReg.fromReg(int_reg),
            .imm = @intCast(bits),
            .size = .size32,
        } };
        try ctx.emit(load_inst);

        const fpu_reg = lower_mod.WritableVReg.allocVReg(.float, ctx);
        const fmov_inst = Inst{ .fmov_from_gpr = .{
            .dst = fpu_reg,
            .src = int_reg,
            .size = .size32,
        } };
        try ctx.emit(fmov_inst);
        return fpu_reg.toReg();
    } else if (in_bits == 64) {
        // From f64
        const min_f64: f64 = switch (signed) {
            true => switch (out_bits) {
                8 => @as(f64, @floatFromInt(std.math.minInt(i8))) - 1.0,
                16 => @as(f64, @floatFromInt(std.math.minInt(i16))) - 1.0,
                32 => @as(f64, @floatFromInt(std.math.minInt(i32))) - 1.0,
                64 => @as(f64, @floatFromInt(std.math.minInt(i64))), // I64_MIN - 1 not precisely representable
                else => unreachable,
            },
            false => -1.0,
        };

        const bits: u64 = @bitCast(min_f64);
        // Load constant into integer register, then move to FPU
        const int_reg = try ctx.getValueReg(lower_mod.Value.new(0), .int);
        const load_inst = Inst{ .mov_imm = .{
            .dst = lower_mod.WritableVReg.fromReg(int_reg),
            .imm = @intCast(bits),
            .size = .size64,
        } };
        try ctx.emit(load_inst);

        const fpu_reg = lower_mod.WritableVReg.allocVReg(.float, ctx);
        const fmov_inst = Inst{ .fmov_from_gpr = .{
            .dst = fpu_reg,
            .src = int_reg,
            .size = .size64,
        } };
        try ctx.emit(fmov_inst);
        return fpu_reg.toReg();
    } else {
        unreachable; // Only 32 and 64 bit floats supported
    }
}

/// Get type bit width (ISLE extractor)
pub fn ty_bits(ty: types.Type) u8 {
    return switch (ty) {
        .I8 => 8,
        .I16 => 16,
        .I32, .F32 => 32,
        .I64, .F64 => 64,
        else => 64, // Default
    };
}

/// Extractor: Match vector type, return (lane_bits, lane_count)
/// Returns null for scalar types
pub fn multi_lane(ty: types.Type) ?struct { u32, u32 } {
    if (!ty.isVector()) return null;
    return .{ ty.laneBits(), ty.laneCount() };
}

/// Extractor: Check if type fits in 64-bit register
/// Returns the type if it fits, null otherwise
pub fn fits_in_64(ty: types.Type) ?types.Type {
    if (ty.bits() <= 64) return ty;
    return null;
}

/// Extractor: Check if vector lanes fit in 32 bits
/// For vectors: check lane size <= 32 bits
/// For scalars: check type size <= 32 bits
pub fn lane_fits_in_32(ty: types.Type) ?types.Type {
    if (ty.isVector()) {
        if (ty.laneBits() <= 32) return ty;
    } else {
        if (ty.bits() <= 32) return ty;
    }
    return null;
}

/// Trap operations (ISLE constructors)
pub fn aarch64_trap(trap_code: TrapCode, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    _ = ctx;
    return Inst{ .udf = .{ .imm = @intFromEnum(trap_code) } };
}

pub fn aarch64_trapz(val: lower_mod.Value, trap_code: TrapCode, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Compare value with zero
    const val_reg = try ctx.getValueReg(val, .int);
    try ctx.emit(Inst{ .cmp_imm = .{ .rn = val_reg, .imm = 0, .is_64 = true } });

    // Branch if non-zero (skip trap)
    const skip_label = ctx.allocLabel();
    try ctx.emit(Inst{ .b_cond = .{ .cond = .ne, .label = skip_label } });

    // Trap if zero
    try ctx.emit(Inst{ .udf = .{ .imm = @intFromEnum(trap_code) } });

    // Skip label
    try ctx.bindLabel(skip_label);
    return Inst{ .invalid = {} };
}

pub fn aarch64_trapnz(val: lower_mod.Value, trap_code: TrapCode, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Compare value with zero
    const val_reg = try ctx.getValueReg(val, .int);
    try ctx.emit(Inst{ .cmp_imm = .{ .rn = val_reg, .imm = 0, .is_64 = true } });

    // Branch if zero (skip trap)
    const skip_label = ctx.allocLabel();
    try ctx.emit(Inst{ .b_cond = .{ .cond = .eq, .label = skip_label } });

    // Trap if non-zero
    try ctx.emit(Inst{ .udf = .{ .imm = @intFromEnum(trap_code) } });

    // Skip label
    try ctx.bindLabel(skip_label);
    return Inst{ .invalid = {} };
}

/// Calculate the maximum floating-point bound for conversion from float to integer.
/// Returns a register containing the maximum representable value plus epsilon.
/// signed: whether the output integer type is signed
/// in_bits: size of input float type (32 or 64)
/// out_bits: size of output integer type (8, 16, 32, or 64)
pub fn max_fp_value(signed: bool, in_bits: u8, out_bits: u8, ctx: *lower_mod.LowerCtx(Inst)) !Reg {
    if (in_bits == 32) {
        // From f32
        const max_f32: f32 = if (signed) switch (out_bits) {
            8 => @as(f32, @floatFromInt(std.math.maxInt(i8))) + 1.0,
            16 => @as(f32, @floatFromInt(std.math.maxInt(i16))) + 1.0,
            32 => @as(f32, @floatFromInt(@as(u64, @bitCast(@as(i64, std.math.maxInt(i32)))) + 1)),
            64 => @as(f32, @floatFromInt(@as(u64, @bitCast(@as(i64, std.math.maxInt(i64)))) + 1)),
            else => unreachable,
        } else switch (out_bits) {
            8 => @as(f32, @floatFromInt(std.math.maxInt(u8))) + 1.0,
            16 => @as(f32, @floatFromInt(std.math.maxInt(u16))) + 1.0,
            32 => @as(f32, @floatFromInt(@as(u64, std.math.maxInt(u32)) + 1)),
            64 => @as(f32, @floatFromInt(@as(u128, std.math.maxInt(u64)) + 1)),
            else => unreachable,
        };

        const bits: u32 = @bitCast(max_f32);
        const int_reg = try ctx.getValueReg(lower_mod.Value.new(0), .int);
        const load_inst = Inst{ .mov_imm = .{
            .dst = lower_mod.WritableVReg.fromReg(int_reg),
            .imm = @intCast(bits),
            .size = .size32,
        } };
        try ctx.emit(load_inst);

        const fpu_reg = lower_mod.WritableVReg.allocVReg(.float, ctx);
        const fmov_inst = Inst{ .fmov_from_gpr = .{
            .dst = fpu_reg,
            .src = int_reg,
            .size = .size32,
        } };
        try ctx.emit(fmov_inst);
        return fpu_reg.toReg();
    } else if (in_bits == 64) {
        // From f64
        const max_f64: f64 = if (signed) switch (out_bits) {
            8 => @as(f64, @floatFromInt(std.math.maxInt(i8))) + 1.0,
            16 => @as(f64, @floatFromInt(std.math.maxInt(i16))) + 1.0,
            32 => @as(f64, @floatFromInt(std.math.maxInt(i32))) + 1.0,
            64 => @as(f64, @floatFromInt(@as(u64, @bitCast(@as(i64, std.math.maxInt(i64)))) + 1)),
            else => unreachable,
        } else switch (out_bits) {
            8 => @as(f64, @floatFromInt(std.math.maxInt(u8))) + 1.0,
            16 => @as(f64, @floatFromInt(std.math.maxInt(u16))) + 1.0,
            32 => @as(f64, @floatFromInt(std.math.maxInt(u32))) + 1.0,
            64 => @as(f64, @floatFromInt(@as(u128, std.math.maxInt(u64)) + 1)),
            else => unreachable,
        };

        const bits: u64 = @bitCast(max_f64);
        const int_reg = try ctx.getValueReg(lower_mod.Value.new(0), .int);
        const load_inst = Inst{ .mov_imm = .{
            .dst = lower_mod.WritableVReg.fromReg(int_reg),
            .imm = @intCast(bits),
            .size = .size64,
        } };
        try ctx.emit(load_inst);

        const fpu_reg = lower_mod.WritableVReg.allocVReg(.float, ctx);
        const fmov_inst = Inst{ .fmov_from_gpr = .{
            .dst = fpu_reg,
            .src = int_reg,
            .size = .size64,
        } };
        try ctx.emit(fmov_inst);
        return fpu_reg.toReg();
    } else {
        unreachable;
    }
}

/// FCVTZS with bounds checking (F32 -> I32).
/// Traps on NaN, overflow, or underflow.
/// NOTE: This is a simplified initial implementation that always uses saturating conversion.
/// Full trap support requires trap blocks and control flow, which is complex.
/// For now, this serves as a placeholder that compiles and provides the function signature.
pub fn aarch64_fcvtzs_32_trap(x: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);

    // TODO: Implement full bounds checking with traps
    // This requires:
    // 1. NaN check: FCMP x, x; if VS then trap
    // 2. Underflow check: FCMP x, min_fp_value; if LE then trap
    // 3. Overflow check: FCMP x, max_fp_value; if GE then trap
    // 4. Then FCVTZS
    //
    // For now, use saturating FCVTZS (native ARM64 behavior)

    return Inst{ .fcvtzs = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = x_reg,
        .dst_size = .size32,
        .src_size = .size32,
    } };
}

/// IABS - Integer absolute value
/// Implemented as: cmp x, 0; neg tmp, x; csel result, x, tmp, ge
pub fn aarch64_iabs(ty: types.Type, x: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const size: Inst.OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

    // Compare x with 0
    const cmp_inst = Inst{ .cmp_imm = .{
        .src = x_reg,
        .imm = 0,
        .size = size,
    } };
    try ctx.emit(cmp_inst);

    // Negate x
    const tmp = lower_mod.WritableVReg.allocVReg(.int, ctx);
    const neg_inst = Inst{ .neg = .{
        .dst = tmp,
        .src = x_reg,
        .size = size,
    } };
    try ctx.emit(neg_inst);

    // Select x if >= 0, otherwise negated value
    return Inst{ .csel = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src1 = x_reg,
        .src2 = tmp.toReg(),
        .cond = .ge,
        .size = size,
    } };
}

/// INSERTLANE - Insert scalar into vector lane (INS)
pub fn aarch64_insertlane(ty: types.Type, vec: lower_mod.Value, x: lower_mod.Value, lane_val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const vec_reg = try getValueReg(ctx, vec);
    const x_reg = try getValueReg(ctx, x);

    // Extract lane index from constant value
    const lane_node = try ctx.getValue(lane_val);
    const lane: u8 = switch (lane_node) {
        .iconst => |c| @intCast(c.value),
        else => return error.NonConstantLane,
    };

    // Determine vector element size from type
    const size: Inst.VecElemSize = switch (ty) {
        types.Type.V8x16 => .size8x16,
        types.Type.V16x8 => .size16x8,
        types.Type.V32x4 => .size32x4,
        types.Type.V64x2 => .size64x2,
        else => return error.UnsupportedType,
    };

    return Inst{ .vec_insert_lane = .{
        .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
        .vec = vec_reg,
        .src = x_reg,
        .lane = lane,
        .size = size,
    } };
}

/// ISPLIT - Split I128 into low and high I64 parts
/// Returns ValueRegs containing the two 64-bit halves
pub fn aarch64_isplit(x: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    // Get the I128 value as ValueRegs (should already be a register pair)
    const x_regs = try ctx.getValueRegs(x);

    // I128 is stored as two I64 registers: [0] = low, [1] = high
    // Just return the existing register pair
    return x_regs;
}

/// Bitcast operations (ISLE constructors)
pub fn aarch64_bitcast_noop(x: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // No-op: just return the value unchanged (type punning in same register file)
    const reg = try ctx.getValueReg(x, .int);
    return Inst{ .mov = .{ .dst = lower_mod.WritableReg.fromReg(reg), .src = reg } };
}

pub fn aarch64_fmov_from_gpr(x: lower_mod.Value, in_ty: types.Type, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const gpr = try ctx.getValueReg(x, .int);
    const fpr = lower_mod.WritableVReg.allocVReg(.float, ctx);
    const size: emit.ScalarSize = if (in_ty.bits() == 32) .size32 else .size64;
    return Inst{ .fmov_from_gpr = .{ .dst = fpr, .src = gpr, .size = size } };
}

pub fn aarch64_fmov_to_gpr(x: lower_mod.Value, out_ty: types.Type, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const fpr = try ctx.getValueReg(x, .float);
    const gpr = lower_mod.WritableReg.allocReg(.int, ctx);
    const size: emit.ScalarSize = if (out_ty.bits() == 32) .size32 else .size64;
    return Inst{ .fmov_to_gpr = .{ .dst = gpr, .src = fpr, .size = size } };
}

/// ABI register accessors (ISLE constructors)
pub fn stack_reg(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    _ = ctx;
    // Return SP register (x31 when used as stack pointer)
    return Inst{ .mov = .{ .dst = lower_mod.WritableReg.fromReg(Reg.gpr(31)), .src = Reg.gpr(31) } };
}

pub fn fp_reg(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    _ = ctx;
    // Return FP register (x29 - frame pointer)
    return Inst{ .mov = .{ .dst = lower_mod.WritableReg.fromReg(Reg.gpr(29)), .src = Reg.gpr(29) } };
}

pub fn link_reg(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    _ = ctx;
    // Return LR register (x30 - link register)
    return Inst{ .mov = .{ .dst = lower_mod.WritableReg.fromReg(Reg.gpr(30)), .src = Reg.gpr(30) } };
}

pub fn pinned_reg(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    _ = ctx;
    // Return pinned register (x28 - typically used for VM context)
    return Inst{ .mov = .{ .dst = lower_mod.WritableReg.fromReg(Reg.gpr(28)), .src = Reg.gpr(28) } };
}

pub fn aarch64_set_pinned_reg(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src = try ctx.getValueReg(val, .int);
    // Move value to pinned register (x28)
    return Inst{ .mov = .{ .dst = lower_mod.WritableReg.fromReg(Reg.gpr(28)), .src = src } };
}

/// Debug operations (ISLE constructors)
pub fn aarch64_debugtrap(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    _ = ctx;
    // BRK #0 - debugger breakpoint
    return Inst{ .brk = .{ .imm = 0 } };
}

/// Stack address computation (ISLE constructor)
pub fn aarch64_stack_addr(stack_slot: StackSlot, offset: i32, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Compute: SP + slot_offset + offset
    const slot_offset = ctx.getStackSlotOffset(stack_slot);
    const total_offset = @as(i64, slot_offset) + @as(i64, offset);

    const dst = lower_mod.WritableReg.allocReg(.int, ctx);

    if (total_offset >= 0 and total_offset <= 4095) {
        // Fits in immediate: ADD dst, SP, #offset
        return Inst{
            .add_imm = .{
                .dst = dst,
                .rn = Reg.gpr(31), // SP
                .imm = @intCast(total_offset),
                .is_64 = true,
            },
        };
    } else {
        // Large offset: MOV + ADD
        const offset_reg = lower_mod.WritableReg.allocReg(.int, ctx);
        try ctx.emit(Inst{ .mov_imm = .{
            .dst = offset_reg,
            .imm = @bitCast(@as(i64, total_offset)),
            .is_64 = true,
        } });
        return Inst{
            .add_rr = .{
                .dst = dst,
                .rn = Reg.gpr(31), // SP
                .rm = offset_reg.toReg(),
                .is_64 = true,
            },
        };
    }
}

/// Symbol address loading (ISLE constructors)
pub fn aarch64_symbol_value(extname: ExternalName, offset: i64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);

    // PC-relative addressing: ADRP + ADD
    // ADRP loads page address, ADD adds page offset
    try ctx.emit(Inst{ .adrp = .{
        .dst = dst,
        .symbol = extname,
    } });

    return Inst{ .add_imm = .{
        .dst = dst,
        .rn = dst.toReg(),
        .imm = @intCast(@mod(offset, 4096)),
        .is_64 = true,
    } };
}

pub fn aarch64_func_addr(extname: ExternalName, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Function address is just symbol_value with offset 0
    return aarch64_symbol_value(extname, 0, ctx);
}

/// Overflow arithmetic (ISLE constructors)
/// Returns ValueRegs: [result, overflow_flag]
pub fn aarch64_uadd_overflow(ty: types.Type, a: lower_mod.Value, b: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const is_64 = ty.bits() == 64;

    // ADDS: Add and set flags
    try ctx.emit(Inst{ .add_s = .{
        .dst = dst,
        .rn = a_reg,
        .rm = b_reg,
        .is_64 = is_64,
    } });

    // CSET: Set register to 1 if carry, 0 otherwise
    const overflow_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .hs, // HS = unsigned higher or same (carry set)
        },
    });

    return lower_mod.ValueRegs.two(dst.toReg(), overflow_reg.toReg());
}

pub fn aarch64_usub_overflow(ty: types.Type, a: lower_mod.Value, b: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const is_64 = ty.bits() == 64;

    // SUBS: Subtract and set flags
    try ctx.emit(Inst{ .sub_s = .{
        .dst = dst,
        .rn = a_reg,
        .rm = b_reg,
        .is_64 = is_64,
    } });

    // CSET: Set register to 1 if borrow (carry clear), 0 otherwise
    const overflow_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .lo, // LO = unsigned lower (borrow/carry clear)
        },
    });

    return lower_mod.ValueRegs.two(dst.toReg(), overflow_reg.toReg());
}

pub fn aarch64_sadd_overflow(ty: types.Type, a: lower_mod.Value, b: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const is_64 = ty.bits() == 64;

    // ADDS: Add and set flags
    try ctx.emit(Inst{ .add_s = .{
        .dst = dst,
        .rn = a_reg,
        .rm = b_reg,
        .is_64 = is_64,
    } });

    // CSET: Set register to 1 if signed overflow (V flag), 0 otherwise
    const overflow_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .vs, // VS = signed overflow
        },
    });

    return lower_mod.ValueRegs.two(dst.toReg(), overflow_reg.toReg());
}

pub fn aarch64_ssub_overflow(ty: types.Type, a: lower_mod.Value, b: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const is_64 = ty.bits() == 64;

    // SUBS: Subtract and set flags
    try ctx.emit(Inst{ .sub_s = .{
        .dst = dst,
        .rn = a_reg,
        .rm = b_reg,
        .is_64 = is_64,
    } });

    // CSET: Set register to 1 if signed overflow (V flag), 0 otherwise
    const overflow_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .vs, // VS = signed overflow
        },
    });

    return lower_mod.ValueRegs.two(dst.toReg(), overflow_reg.toReg());
}

/// Tail call operations (ISLE constructors)
pub fn aarch64_return_call(sig_ref: SigRef, name: ExternalName, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Tail call: marshal args, deallocate frame, branch (not call)
    _ = sig_ref;
    _ = args;

    // TODO: Proper ABI argument marshaling
    // For now, emit simple sequence:

    // 1. Deallocate stack frame (restore SP)
    const frame_size = ctx.getFrameSize();
    if (frame_size > 0) {
        try ctx.emit(Inst{
            .add_imm = .{
                .dst = lower_mod.WritableReg.fromReg(Reg.gpr(31)), // SP
                .rn = Reg.gpr(31),
                .imm = @intCast(frame_size),
                .is_64 = true,
            },
        });
    }

    // 2. Branch to target (B, not BL - no link)
    return Inst{ .b = .{ .target = .{ .symbol = name } } };
}

pub fn aarch64_return_call_indirect(sig_ref: SigRef, ptr: lower_mod.Value, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Indirect tail call: marshal args, deallocate frame, branch via register
    _ = sig_ref;
    _ = args;

    const ptr_reg = try ctx.getValueReg(ptr, .int);

    // Deallocate stack frame
    const frame_size = ctx.getFrameSize();
    if (frame_size > 0) {
        try ctx.emit(Inst{
            .add_imm = .{
                .dst = lower_mod.WritableReg.fromReg(Reg.gpr(31)), // SP
                .rn = Reg.gpr(31),
                .imm = @intCast(frame_size),
                .is_64 = true,
            },
        });
    }

    // Branch via register (BR, not BLR - no link)
    return Inst{ .br = .{ .rn = ptr_reg } };
}

/// Vector test operations (ISLE constructors)
pub fn aarch64_vall_true(x: lower_mod.Value, ty: types.Type, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try ctx.getValueReg(x, .vector);
    const vec_size = vectorSizeFromType(ty);

    // Use UMINV to get minimum of all lanes
    const min_reg = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_uminv = .{
        .dst = min_reg,
        .src = x_reg,
        .size = vec_size,
    } });

    // Extract scalar and compare with 0
    const scalar_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .mov_from_vec = .{
        .dst = scalar_reg,
        .src = min_reg.toReg(),
        .lane = 0,
        .size = .size64,
    } });

    // Compare: all true if min != 0
    try ctx.emit(Inst{ .cmp_imm = .{
        .rn = scalar_reg.toReg(),
        .imm = 0,
        .is_64 = true,
    } });

    // CSET: Set result to 1 if NE, 0 otherwise
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{ .cset = .{ .dst = dst, .cond = .ne } };
}

pub fn aarch64_vany_true(x: lower_mod.Value, ty: types.Type, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try ctx.getValueReg(x, .vector);
    const vec_size = vectorSizeFromType(ty);

    // Use UMAXV to get maximum of all lanes
    const max_reg = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_umaxv = .{
        .dst = max_reg,
        .src = x_reg,
        .size = vec_size,
    } });

    // Extract scalar and compare with 0
    const scalar_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .mov_from_vec = .{
        .dst = scalar_reg,
        .src = max_reg.toReg(),
        .lane = 0,
        .size = .size64,
    } });

    // Compare: any true if max != 0
    try ctx.emit(Inst{ .cmp_imm = .{
        .rn = scalar_reg.toReg(),
        .imm = 0,
        .is_64 = true,
    } });

    // CSET: Set result to 1 if NE, 0 otherwise
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{ .cset = .{ .dst = dst, .cond = .ne } };
}

pub fn aarch64_vhigh_bits(vec: lower_mod.Value, ty: types.Type, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const vec_reg = try ctx.getValueReg(vec, .vector);
    const lane_bits = ty.laneBits();

    // Extract high bit from each lane by shifting and accumulating
    // For I8X16: shift each byte left by 7, then ADDV to sum
    const shift_amount: u8 = @intCast(lane_bits - 1);

    // SHL to move high bit to position
    const shifted = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_shl_imm = .{
        .dst = shifted,
        .src = vec_reg,
        .shift = shift_amount,
        .size = vectorSizeFromType(ty),
    } });

    // ADDV to sum all lanes (creates bitmask)
    const sum_reg = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_addv = .{
        .dst = sum_reg,
        .src = shifted.toReg(),
        .size = vectorSizeFromType(ty),
    } });

    // Extract to GPR
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{ .mov_from_vec = .{
        .dst = dst,
        .src = sum_reg.toReg(),
        .lane = 0,
        .size = .size64,
    } };
}

fn vectorSizeFromType(ty: types.Type) emit.VectorSize {
    return switch (ty) {
        .I8X16 => .Size8x16,
        .I16X8 => .Size16x8,
        .I32X4 => .Size32x4,
        .I64X2 => .Size64x2,
        else => .Size8x16, // Default
    };
}

/// Call operations (ISLE constructors)
pub fn aarch64_call(sig_ref: SigRef, name: ExternalName, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    // Marshal arguments according to ABI
    // TODO: Full ABI argument marshaling
    _ = sig_ref;
    _ = args;

    // Direct call: BL (branch with link)
    try ctx.emit(Inst{ .bl = .{ .target = .{ .symbol = name } } });

    // Return value in x0 (simplified - should handle multi-return)
    return lower_mod.ValueRegs.one(Reg.gpr(0));
}

pub fn aarch64_call_indirect(sig_ref: SigRef, ptr: lower_mod.Value, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    // Marshal arguments according to ABI
    // TODO: Full ABI argument marshaling
    _ = sig_ref;
    _ = args;

    const ptr_reg = try ctx.getValueReg(ptr, .int);

    // Indirect call: BLR (branch with link to register)
    try ctx.emit(Inst{ .blr = .{ .rn = ptr_reg } });

    // Return value in x0 (simplified - should handle multi-return)
    return lower_mod.ValueRegs.one(Reg.gpr(0));
}

/// Shuffle pattern extractors (ISLE extern extractors)
/// Check if 128-bit immediate represents duplication of a single 8-bit lane
pub fn shuffle_dup8_from_imm(imm: u128) ?u8 {
    // Extract first byte
    const lane: u8 = @truncate(imm);

    // Check if all 16 bytes are the same
    var i: u8 = 0;
    while (i < 16) : (i += 1) {
        const byte: u8 = @truncate(imm >> (@as(u7, i) * 8));
        if (byte != lane) return null;
    }

    // Return lane index (0-15)
    return lane;
}

pub fn shuffle_dup16_from_imm(imm: u128) ?u8 {
    // Extract first 16-bit value (bytes 0-1)
    const lane16: u16 = @truncate(imm);

    // Check if all 8 halfwords are the same
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        const hword: u16 = @truncate(imm >> (@as(u7, i) * 16));
        if (hword != lane16) return null;
    }

    // Return lane index (lane16 should be 0-7 repeated as 0x0100, 0x0302, etc.)
    return @truncate(lane16);
}

pub fn shuffle_dup32_from_imm(imm: u128) ?u8 {
    // Extract first 32-bit value (bytes 0-3)
    const lane32: u32 = @truncate(imm);

    // Check if all 4 words are the same
    var i: u8 = 0;
    while (i < 4) : (i += 1) {
        const word: u32 = @truncate(imm >> (@as(u7, i) * 32));
        if (word != lane32) return null;
    }

    // Return lane index (0-3)
    return @truncate(lane32);
}

pub fn shuffle_dup64_from_imm(imm: u128) ?u8 {
    // Extract low and high 64-bit values
    const low: u64 = @truncate(imm);
    const high: u64 = @truncate(imm >> 64);

    // Check if both are the same
    if (low != high) return null;

    // Return lane index (0-1)
    return @truncate(low);
}

pub fn vec_extract_imm4_from_immediate(imm: u128) ?u8 {
    // Check if pattern is: n, n+1, n+2, ..., n+15 (consecutive bytes)
    const first_byte: u8 = @truncate(imm);

    var i: u8 = 0;
    while (i < 16) : (i += 1) {
        const expected: u8 = @truncate(@as(u16, first_byte) + i);
        const actual: u8 = @truncate(imm >> (@as(u7, i) * 8));
        if (actual != expected) return null;
    }

    // Return starting byte offset (must be < 16 for valid EXT)
    if (first_byte < 16) return first_byte;
    return null;
}

/// u128_from_immediate - Extract u128 constant from Immediate
/// Used for matching specific shuffle patterns (UZP/ZIP/TRN/REV)
pub fn u128_from_immediate(expected: u128, actual: u128) ?u128 {
    if (expected == actual) return actual;
    return null;
}

/// Shuffle operations (ISLE constructor)
pub fn aarch64_shuffle_tbl(a: lower_mod.Value, b: lower_mod.Value, mask: u128, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try ctx.getValueReg(a, .vector);
    const b_reg = try ctx.getValueReg(b, .vector);

    // Load 128-bit mask into vector register
    const mask_reg = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    // Load mask as two 64-bit immediates
    const mask_lo: u64 = @truncate(mask);
    const mask_hi: u64 = @truncate(mask >> 64);

    // MOV immediate to vector (using FMOV for 64-bit chunks)
    const tmp_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    const tmp_hi = lower_mod.WritableReg.allocReg(.int, ctx);

    try ctx.emit(Inst{ .mov_imm = .{
        .dst = tmp_lo,
        .imm = @bitCast(mask_lo),
        .is_64 = true,
    } });

    try ctx.emit(Inst{ .mov_imm = .{
        .dst = tmp_hi,
        .imm = @bitCast(mask_hi),
        .is_64 = true,
    } });

    // Move to vector register (INS or FMOV)
    try ctx.emit(Inst{ .fmov_from_gpr = .{
        .dst = mask_reg,
        .src = tmp_lo.toReg(),
        .size = .size64,
    } });

    try ctx.emit(Inst{ .vec_insert_lane = .{
        .dst = mask_reg,
        .vec = mask_reg.toReg(),
        .src = tmp_hi.toReg(),
        .lane = 1,
        .size = .Size64x2,
    } });

    // TBL2: Two-register table lookup
    // Concatenates a and b as 256-bit table, indexes with mask
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    return Inst{ .vec_tbl2 = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .idx = mask_reg.toReg(),
    } };
}
