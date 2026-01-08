/// ISLE extractor and constructor helpers for aarch64.
/// These functions are called from ISLE-generated code via extern declarations.
const std = @import("std");
const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const Reg = root.aarch64_inst.Reg;
const PReg = root.machinst.PReg;
const Imm12 = root.aarch64_inst.Imm12;
const ImmShift = root.aarch64_inst.ImmShift;
const ImmLogic = root.aarch64_inst.ImmLogic;
const ExtendOp = root.aarch64_inst.ExtendOp;
const VecALUOp = root.aarch64_inst.VecALUOp;
const VecMisc2 = root.aarch64_inst.VecMisc2;
const lower_mod = root.lower;
const types = root.types;
const trapcode = root.trapcode;
const emit = @import("emit.zig");
const entities = root.entities;

// Type aliases for IR types
const Type = types.Type;
const IntCC = root.condcodes.IntCC;
const FloatCC = root.condcodes.FloatCC;
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

const VecALUModOp = enum {
    Fmla,
    Fmls,
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
    const def = ctx.func.dfg.valueDef(value);
    const inst = def.inst orelse return null;

    const inst_data = ctx.func.dfg.insts.get(inst) orelse return null;
    if (inst_data.* != .unary_imm) return null;
    if (inst_data.unary_imm.opcode != .iconst) return null;

    return inst_data.unary_imm.imm.value;
}

/// Constructor: Convert Imm12 back to u64.
pub fn u64_from_imm12(imm: Imm12) u64 {
    return imm.toU64();
}

/// Constructor: Convert u8 to Imm12 (always succeeds for u8).
pub fn u8_into_imm12(val: u8) Imm12 {
    return .{ .bits = val, .shift12 = false };
}

/// Constructor: Convert u64 to u6 (for shift amounts).
pub fn u64_to_u6(val: u64) u6 {
    return @intCast(val & 0x3F);
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
/// AArch64 LDR has 12-bit unsigned immediate scaled by access size.
/// Returns the offset if valid (0-4095 scaled), null otherwise.
pub fn valid_ldr_imm_offset(ty: types.Type, offset: u64) ?u64 {
    // LDR immediate encoding: offset = imm12 * size
    // imm12 is 12-bit unsigned (0-4095)
    const size = ty.bytes();
    const max_offset = 4095 * size;

    // Offset must be aligned to access size
    if (offset % size != 0) return null;
    if (offset > max_offset) return null;

    return offset;
}

/// Extractor: Check if offset is valid for store immediate addressing.
/// AArch64 STR has 12-bit unsigned immediate scaled by access size.
/// Returns the offset if valid (0-4095 scaled), null otherwise.
pub fn valid_str_imm_offset(val: lower_mod.Value, offset: u64) ?u64 {
    // STR immediate encoding: offset = imm12 * size
    // imm12 is 12-bit unsigned (0-4095)
    const ty = val.type;
    const size = ty.bytes();
    const max_offset = 4095 * size;

    // Offset must be aligned to access size
    if (offset % size != 0) return null;
    if (offset > max_offset) return null;

    return offset;
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
        .ult => .cc, // lo/cc are same: carry clear
        .uge => .cs, // hs/cs are same: carry set
        .ugt => .hi,
        .ule => .ls,
    };
}

/// ISLE snake_case alias for intccToCondCode
pub const intcc_to_cond_code = intccToCondCode;

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

/// Constructor: Create CCMP instruction (register, register).
/// Conditional compare - compares if condition holds, else sets flags to nzcv.
pub fn aarch64_ccmp_rr(ty: root.types.Type, x: lower_mod.Value, y: lower_mod.Value, nzcv: u4, cond: root.aarch64_inst.CondCode, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToOperandSize(ty);
    const reg_x = try getValueReg(ctx, x);
    const reg_y = try getValueReg(ctx, y);
    return Inst{ .ccmp = .{
        .src1 = reg_x,
        .src2 = reg_y,
        .nzcv = nzcv,
        .cond = cond,
        .size = size,
    } };
}

/// Constructor: Create CCMP instruction (register, immediate).
/// Conditional compare with 5-bit immediate.
pub fn aarch64_ccmp_imm(ty: root.types.Type, x: lower_mod.Value, imm: u5, nzcv: u4, cond: root.aarch64_inst.CondCode, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToOperandSize(ty);
    const reg_x = try getValueReg(ctx, x);
    return Inst{ .ccmp_imm = .{
        .src = reg_x,
        .imm = imm,
        .nzcv = nzcv,
        .cond = cond,
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

/// Constructor: Create CSEL (conditional select) with flags-producing instruction.
/// This emits the flags-producing instruction (e.g., CMP or CCMP), then emits CSEL.
/// Used for select patterns where we have a comparison and want to choose between two values.
pub fn aarch64_csel(
    ty: root.types.Type,
    true_val: lower_mod.Value,
    false_val: lower_mod.Value,
    flags_inst: Inst,
    cc: root.condcodes.IntCC,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    // Emit the flags-producing instruction (CMP, CCMP, etc.)
    try ctx.emit(flags_inst);

    // Get registers for true/false values
    const true_reg = try getValueReg(ctx, true_val);
    const false_reg = try getValueReg(ctx, false_val);

    // Allocate destination register
    const dst = lower_mod.WritableVReg.allocVReg(.int, ctx);

    // Convert IntCC to CondCode
    const cond = intccToCondCode(cc);

    // Determine operand size based on result type
    const size = typeToOperandSize(ty);

    // Emit CSEL instruction
    return Inst{ .csel = .{
        .dst = dst,
        .src1 = true_reg,
        .src2 = false_reg,
        .cond = cond,
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

/// Constructor: Create MUL instruction (register, register).
pub fn aarch64_mul_rr(ty: root.types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const size = typeToOperandSize(ty);
    const reg_x = try getValueReg(ctx, x);
    const reg_y = try getValueReg(ctx, y);
    const dst = lower_mod.WritableVReg.allocVReg(.int, ctx);
    return Inst{ .mul_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
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

/// Helper: Convert IR type to register class.
fn typeToRegClass(ty: root.types.Type) root.machinst.RegClass {
    if (ty.isVector()) {
        return .vector;
    } else if (ty.isFloat()) {
        return .float;
    } else {
        return .int;
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

/// REV16 - Reverse bytes within 16-bit halfwords
pub fn rev16(a: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try ctx.getValueReg(a, .vector);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .vec_rev16 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src = a_reg, .size = size } };
}

/// REV32 - Reverse bytes within 32-bit words
pub fn rev32(a: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try ctx.getValueReg(a, .vector);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .vec_rev32 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src = a_reg, .size = size } };
}

/// REV64 - Reverse bytes within 64-bit doublewords
pub fn rev64(a: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try ctx.getValueReg(a, .vector);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .vec_rev64 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src = a_reg, .size = size } };
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

/// AND (immediate) - Bitwise AND with logical immediate
pub fn aarch64_and_imm(ty: types.Type, x: lower_mod.Value, imm: ImmLogic, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const size = typeToOperandSize(ty);
    _ = size; // ImmLogic already encodes size
    return Inst{ .and_imm = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = x_reg,
        .imm = imm,
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

/// Extractor: Match only 128-bit vector types
pub fn ty_vec128(ty: types.Type) ?types.Type {
    if (ty.isVector() and ty.bytes() == 16) {
        return ty;
    }
    return null;
}

/// Extractor: Match only 128-bit integer vector types
pub fn ty_vec128_int(ty: types.Type) ?types.Type {
    if (ty.isVector() and ty.bytes() == 16) {
        const lane_ty = ty.laneType();
        if (lane_ty.isInt()) {
            return ty;
        }
    }
    return null;
}

/// Extractor: Match everything except I64X2
pub fn not_i64x2(ty: types.Type) ?types.Type {
    if (ty == types.I64X2) {
        return null;
    }
    return ty;
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

pub fn aarch64_get_pinned_reg(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    _ = ctx;
    // Return pinned register (x28 - typically used for VM context)
    return Inst{ .mov = .{ .dst = lower_mod.WritableReg.fromReg(Reg.gpr(28)), .src = Reg.gpr(28) } };
}

pub fn aarch64_set_pinned_reg(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src = try ctx.getValueReg(val, .int);
    // Move value to pinned register (x28)
    return Inst{ .mov = .{ .dst = lower_mod.WritableReg.fromReg(Reg.gpr(28)), .src = src } };
}

/// Stack switching for fiber/coroutine support (ISLE constructors)
pub fn aarch64_stack_switch(old_sp_addr: lower_mod.Value, new_sp_addr: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Stack switch sequence:
    // 1. MOV X<tmp>, SP              - Save current SP
    // 2. STR X<tmp>, [old_sp_addr]   - Store to old_sp_addr
    // 3. LDR X<new>, [new_sp_addr]   - Load from new_sp_addr
    // 4. MOV SP, X<new>              - Switch to new SP

    const sp = Reg.gpr(31); // SP register
    const tmp = lower_mod.WritableReg.allocReg(.int, ctx);

    // Save current SP to temporary
    try ctx.emit(Inst{ .mov_rr = .{
        .dst = tmp,
        .src = sp,
        .size = .size64,
    } });

    // Store old SP to memory
    const old_addr_reg = try ctx.getValueReg(old_sp_addr, .int);
    try ctx.emit(Inst{ .str = .{
        .src = tmp.toReg(),
        .base = old_addr_reg,
        .offset = 0,
        .size = .size64,
    } });

    // Load new SP from memory
    const new_addr_reg = try ctx.getValueReg(new_sp_addr, .int);
    const new_sp = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .ldr = .{
        .dst = new_sp,
        .base = new_addr_reg,
        .offset = 0,
        .size = .size64,
    } });

    // Switch to new stack pointer
    return Inst{ .mov_rr = .{
        .dst = lower_mod.WritableReg.from(sp),
        .src = new_sp.toReg(),
        .size = .size64,
    } };
}

/// TLS operations (ISLE constructors)
pub fn tls_local_exec(offset: u64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Local-exec TLS model: simplest, for executables only
    // Sequence: MRS + ADD
    //   MRS Xd, TPIDR_EL0     // Read thread pointer
    //   ADD Xd, Xd, #offset   // Add TLS variable offset

    const dst = lower_mod.WritableReg.allocReg(.int, ctx);

    // Read thread pointer register
    try ctx.emit(Inst{ .mrs = .{
        .dst = dst,
        .sysreg = Inst.SystemReg.tpidr_el0,
    } });

    // Add TLS offset to get variable address
    // For now, use immediate offset (will need relocation support later)
    if (offset == 0) {
        // No offset, just return thread pointer
        return Inst{ .mov_rr = .{
            .dst = dst,
            .src = dst.toReg(),
            .size = .size64,
        } };
    } else if (offset <= 0xFFF) {
        // Small offset fits in ADD immediate
        return Inst{ .add_imm = .{
            .dst = dst,
            .src = dst.toReg(),
            .imm = @intCast(offset),
            .size = .size64,
        } };
    } else {
        // Large offset: MOV immediate + ADD
        const offset_reg = lower_mod.WritableReg.allocReg(.int, ctx);
        try ctx.emit(Inst{ .mov_imm = .{
            .dst = offset_reg,
            .imm = offset,
            .size = .size64,
        } });
        return Inst{ .add_rr = .{
            .dst = dst,
            .src1 = dst.toReg(),
            .src2 = offset_reg.toReg(),
            .size = .size64,
        } };
    }
}

pub fn tls_init_exec(extname: ExternalName, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Initial-exec TLS model: TLS offset loaded from GOT
    // Sequence: ADRP + LDR + MRS + ADD
    //   ADRP Xtmp, :gottprel:symbol   // Load GOT page address
    //   LDR  Xtmp, [Xtmp, :gottprel_lo12:symbol]  // Load TLS offset from GOT
    //   MRS  Xd, TPIDR_EL0            // Read thread pointer
    //   ADD  Xd, Xd, Xtmp             // Add TLS offset to thread pointer

    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const tmp = lower_mod.WritableReg.allocReg(.int, ctx);

    // ADRP: Load GOT page containing TLS offset
    try ctx.emit(Inst{
        .adrp = .{
            .dst = tmp,
            .symbol = extname,
            // Note: relocation will be aarch64_tlsie_adr_gottprel_page21
        },
    });

    // LDR: Load TLS offset from GOT entry
    try ctx.emit(Inst{
        .ldr_imm = .{
            .dst = tmp,
            .base = tmp.toReg(),
            .offset = 0, // Will be filled by relocation
            .size = .size64,
            .sign_extend = false,
            // Note: relocation will be aarch64_tlsie_ld64_gottprel_lo12_nc
        },
    });

    // MRS: Read thread pointer
    try ctx.emit(Inst{ .mrs = .{
        .dst = dst,
        .sysreg = Inst.SystemReg.tpidr_el0,
    } });

    // ADD: Add TLS offset to thread pointer to get variable address
    return Inst{ .add_rr = .{
        .dst = dst,
        .src1 = dst.toReg(),
        .src2 = tmp.toReg(),
        .size = .size64,
    } };
}

pub fn tls_general_dynamic(extname: ExternalName, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // General-dynamic TLS model: Full dynamic TLS via descriptors
    // Modern sequence with TLS descriptors:
    //   ADRP Xtmp, :tlsdesc:symbol         // Load descriptor page
    //   LDR  Xfn, [Xtmp, :tlsdesc_lo12:symbol]  // Load descriptor function
    //   ADD  X0, Xtmp, :tlsdesc_lo12:symbol     // Descriptor argument in X0
    //   BLR  Xfn                           // Call descriptor resolver
    //   ADD  Xd, X0, TPIDR_EL0             // Add thread pointer to result
    //
    // Note: Modern linkers optimize this to IE or LE when possible

    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const tmp = lower_mod.WritableReg.allocReg(.int, ctx);
    const fn_reg = lower_mod.WritableReg.allocReg(.int, ctx);

    // ADRP: Load TLS descriptor page
    try ctx.emit(Inst{
        .adrp = .{
            .dst = tmp,
            .symbol = extname,
            // Note: relocation will be aarch64_tlsdesc_adr_page21
        },
    });

    // LDR: Load descriptor function pointer
    try ctx.emit(Inst{
        .ldr_imm = .{
            .dst = fn_reg,
            .base = tmp.toReg(),
            .offset = 0, // Will be filled by relocation
            .size = .size64,
            .sign_extend = false,
            // Note: relocation will be aarch64_tlsdesc_ld64_lo12
        },
    });

    // ADD: Prepare descriptor argument in X0
    const x0 = Reg.gpr(0); // X0 - first argument register
    const x0_writable = lower_mod.WritableReg.fromReg(x0);
    try ctx.emit(Inst{
        .add_imm = .{
            .dst = x0_writable,
            .src = tmp.toReg(),
            .imm = 0, // Will be filled by relocation
            .size = .size64,
            // Note: relocation will be aarch64_tlsdesc_add_lo12
        },
    });

    // BLR: Call TLS descriptor resolver
    try ctx.emit(Inst{
        .blr = .{
            .rn = fn_reg.toReg(),
            // Note: this call has special semantics - aarch64_tlsdesc_call
            // X0 contains argument, result returned in X0
        },
    });

    // MRS: Read thread pointer
    try ctx.emit(Inst{ .mrs = .{
        .dst = dst,
        .sysreg = Inst.SystemReg.tpidr_el0,
    } });

    // ADD: Add thread pointer to TLS offset (in X0) to get variable address
    return Inst{ .add_rr = .{
        .dst = dst,
        .src1 = dst.toReg(),
        .src2 = x0,
        .size = .size64,
    } };
}

/// Dynamic stack operations (ISLE constructors)
pub fn dynamic_stack_addr(offset: u64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Get dynamic stack pointer register (X19)
    // This requires dynamic allocations to be enabled in the ABI
    const dyn_sp = Reg.gpr(19); // X19 - dynamic stack pointer
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);

    // Compute address: ADD Xd, X19, #offset
    if (offset == 0) {
        // Just move the dynamic SP
        return Inst{ .mov_rr = .{
            .dst = dst,
            .src = dyn_sp,
            .size = .size64,
        } };
    } else if (offset <= 0xFFF) {
        // Small offset fits in ADD immediate
        return Inst{ .add_imm = .{
            .dst = dst,
            .src = dyn_sp,
            .imm = @intCast(offset),
            .size = .size64,
        } };
    } else {
        // Large offset - load into register first
        const offset_reg = lower_mod.WritableReg.allocReg(.int, ctx);
        try ctx.emit(Inst{ .mov_imm = .{
            .dst = offset_reg,
            .imm = offset,
            .size = .size64,
        } });
        return Inst{ .add_rr = .{
            .dst = dst,
            .src1 = dyn_sp,
            .src2 = offset_reg.toReg(),
            .size = .size64,
        } };
    }
}

pub fn dynamic_stack_load(ty: Type, offset: u64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Load from dynamic stack: LDR Xd/Vd, [X19, #offset]
    const dyn_sp = Reg.gpr(19); // X19 - dynamic stack pointer

    // Compute address first if offset doesn't fit in load immediate
    const max_load_offset = 32760; // 12-bit scaled by 8 for 64-bit loads
    if (offset > max_load_offset) {
        // Compute address in temp register
        const addr_reg = lower_mod.WritableReg.allocReg(.int, ctx);
        try ctx.emit(try dynamic_stack_addr(offset, ctx));
        // Then load from [addr_reg, #0]
        const load_base = addr_reg.toReg();
        return switch (ty) {
            .I8, .I16, .I32, .I64 => Inst{ .ldr = .{
                .dst = lower_mod.WritableReg.allocReg(.int, ctx),
                .base = load_base,
                .offset = 0,
                .size = typeToOperandSize(ty),
            } },
            .F32, .F64 => Inst{ .fldr = .{
                .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
                .base = load_base,
                .offset = 0,
                .size = typeToOperandSize(ty),
            } },
            else => unreachable,
        };
    } else {
        // Direct load with offset
        return switch (ty) {
            .I8, .I16, .I32, .I64 => Inst{ .ldr = .{
                .dst = lower_mod.WritableReg.allocReg(.int, ctx),
                .base = dyn_sp,
                .offset = @intCast(offset),
                .size = typeToOperandSize(ty),
            } },
            .F32, .F64 => Inst{ .fldr = .{
                .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
                .base = dyn_sp,
                .offset = @intCast(offset),
                .size = typeToOperandSize(ty),
            } },
            else => unreachable,
        };
    }
}

pub fn dynamic_stack_store(ty: Type, val: lower_mod.Value, offset: u64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Store to dynamic stack: STR Xs/Vs, [X19, #offset]
    const dyn_sp = Reg.gpr(19); // X19 - dynamic stack pointer

    // Compute address first if offset doesn't fit in store immediate
    const max_store_offset = 32760; // 12-bit scaled by 8 for 64-bit stores
    if (offset > max_store_offset) {
        // Compute address in temp register
        const addr_reg = lower_mod.WritableReg.allocReg(.int, ctx);
        try ctx.emit(try dynamic_stack_addr(offset, ctx));
        // Then store to [addr_reg, #0]
        const store_base = addr_reg.toReg();
        return switch (ty) {
            .I8, .I16, .I32, .I64 => {
                const src = try ctx.getValueReg(val, .int);
                return Inst{ .str = .{
                    .src = src,
                    .base = store_base,
                    .offset = 0,
                    .size = typeToOperandSize(ty),
                } };
            },
            .F32, .F64 => {
                const src = try ctx.getValueVReg(val, .float);
                return Inst{ .fstr = .{
                    .src = src,
                    .base = store_base,
                    .offset = 0,
                    .size = typeToOperandSize(ty),
                } };
            },
            else => unreachable,
        };
    } else {
        // Direct store with offset
        return switch (ty) {
            .I8, .I16, .I32, .I64 => {
                const src = try ctx.getValueReg(val, .int);
                return Inst{ .str = .{
                    .src = src,
                    .base = dyn_sp,
                    .offset = @intCast(offset),
                    .size = typeToOperandSize(ty),
                } };
            },
            .F32, .F64 => {
                const src = try ctx.getValueVReg(val, .float);
                return Inst{ .fstr = .{
                    .src = src,
                    .base = dyn_sp,
                    .offset = @intCast(offset),
                    .size = typeToOperandSize(ty),
                } };
            },
            else => unreachable,
        };
    }
}

/// Debug operations (ISLE constructors)
pub fn aarch64_debugtrap(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    _ = ctx;
    // BRK #0 - debugger breakpoint
    return Inst{ .brk = .{ .imm = 0 } };
}

/// Float constant constructors (ISLE constructors)
pub fn constant_f32(bits: u32, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const dst_fpr = lower_mod.WritableVReg.allocVReg(.float, ctx);

    // Load from constant pool using LDR literal
    // During emission, the constant is added to the pool and LDR literal is emitted
    return Inst{ .fpload_const = .{
        .dst = dst_fpr,
        .bits = bits,
        .size = .size32,
    } };
}

pub fn constant_f64(bits: u64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const dst_fpr = lower_mod.WritableVReg.allocVReg(.float, ctx);

    // Load from constant pool using LDR literal
    // During emission, the constant is added to the pool and LDR literal is emitted
    return Inst{ .fpload_const = .{
        .dst = dst_fpr,
        .bits = bits,
        .size = .size64,
    } };
}

pub fn constant_v128(imm: u128, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    // Strategy: try optimized encodings first, fall back to load from constant pool

    // 1. Check if all zeros - use EOR Vd, Vd, Vd
    if (imm == 0) {
        // EOR (vector XOR) with self produces zero
        return Inst{ .vec_eor = .{
            .dst = dst,
            .src1 = dst.toReg(),
            .src2 = dst.toReg(),
            .size = Inst.FpuOperandSize.size128,
        } };
    }

    // 2. Check if splat of single byte
    const first_byte: u8 = @truncate(imm);
    var is_splat_byte = true;
    var i: u7 = 1;
    while (i < 16) : (i += 1) {
        const byte: u8 = @truncate(imm >> (i * 8));
        if (byte != first_byte) {
            is_splat_byte = false;
            break;
        }
    }

    if (is_splat_byte) {
        // Use DUP to splat the byte value
        const tmp_gpr = lower_mod.WritableReg.allocReg(.int, ctx);
        try ctx.emit(Inst{ .mov_imm = .{
            .dst = tmp_gpr,
            .imm = first_byte,
            .is_64 = false,
        } });

        return Inst{ .vec_dup = .{
            .dst = dst,
            .src = tmp_gpr.toReg(),
            .size = Inst.VecElemSize.size8x16,
        } };
    }

    // 4. Fall back to constant pool load
    // Use fpload_const to load 128-bit constant from pool
    // Note: only lower 64 bits are used since u128 > u64
    // For full 128-bit support, would need to store both halves
    const lo: u64 = @truncate(imm);

    return Inst{ .fpload_const = .{
        .dst = dst,
        .bits = lo,
        .size = .size128,
    } };
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
    return Inst{ .br = .{ .target = ptr_reg } };
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
    // Validate signature if available
    if (ctx.getSig(sig_ref)) |sig| {
        // Check argument count matches
        if (args.len != sig.params.items.len) {
            std.log.err("Call argument count mismatch: got {}, expected {}", .{ args.len, sig.params.items.len });
            return error.SignatureArgumentCountMismatch;
        }

        // Check argument types match
        for (args, 0..) |arg_value, i| {
            const arg_type = ctx.func.dfg.valueType(arg_value);
            const param_type = sig.params.items[i].value_type;
            if (!arg_type.eq(param_type)) {
                std.log.err("Call argument {} type mismatch: got {}, expected {}", .{ i, arg_type, param_type });
                return error.SignatureArgumentTypeMismatch;
            }
        }
    }

    // AAPCS64 calling convention:
    // - First 8 integer args in X0-X7
    // - First 8 FP/SIMD args in V0-V7
    // - Remaining args on stack (8-byte aligned, pushed in order)

    // Marshal arguments to ABI registers and stack
    var int_count: u32 = 0;
    var fp_count: u32 = 0;
    var stack_offset: u32 = 0;

    for (args) |arg_value| {
        const arg_type = ctx.func.dfg.valueType(arg_value);
        const is_fp = arg_type.isFloat() or arg_type.isVector();

        if (is_fp) {
            if (fp_count < 8) {
                // FP/SIMD args in V0-V7
                const arg_reg = try ctx.getValueReg(arg_value, .float);
                const abi_reg_num: u8 = @intCast(fp_count);
                const abi_reg = Reg.fpr(abi_reg_num);

                // Emit move to ABI register if not already there
                if (!arg_reg.toReg().eq(abi_reg)) {
                    try ctx.emit(Inst{ .fmov_rr = .{
                        .dst = lower_mod.WritableReg.fromReg(abi_reg),
                        .src = arg_reg.toReg(),
                        .size = typeToFpuOperandSize(arg_type),
                    } });
                }
                fp_count += 1;
            } else {
                // FP args beyond V7 go on stack
                const arg_reg = try ctx.getValueReg(arg_value, .float);
                try ctx.emit(Inst{
                    .str_fp = .{
                        .src = arg_reg.toReg(),
                        .base = Reg.gpr(31), // SP
                        .offset = @intCast(stack_offset),
                        .size = typeToFpuOperandSize(arg_type),
                    },
                });
                stack_offset += 8;
            }
        } else {
            if (int_count < 8) {
                // Integer args in X0-X7
                const arg_reg = try ctx.getValueReg(arg_value, .int);
                const abi_reg_num: u8 = @intCast(int_count);
                const abi_reg = Reg.gpr(abi_reg_num);

                // Emit move to ABI register if not already there
                if (!arg_reg.toReg().eq(abi_reg)) {
                    try ctx.emit(Inst{ .mov_rr = .{
                        .dst = lower_mod.WritableReg.fromReg(abi_reg),
                        .src = arg_reg.toReg(),
                        .size = .size64,
                    } });
                }
                int_count += 1;
            } else {
                // Integer args beyond X7 go on stack
                const arg_reg = try ctx.getValueReg(arg_value, .int);
                try ctx.emit(Inst{
                    .str = .{
                        .src = arg_reg.toReg(),
                        .base = Reg.gpr(31), // SP
                        .offset = @intCast(stack_offset),
                        .size = .size64,
                    },
                });
                stack_offset += 8;
            }
        }
    }

    // Direct call: BL (branch with link)
    // Convert ExternalName to string for CallTarget
    // TODO: Proper ExternalName->string conversion (currently using testcase name)
    const symbol_name = switch (name) {
        .testcase => |n| n,
        .user => |u| blk: {
            // For now, format user external names as "u{namespace}:{index}"
            // This is a temporary workaround - proper symbol resolution TBD
            _ = u;
            break :blk "external_user_func";
        },
    };
    try ctx.emit(Inst{ .bl = .{ .target = .{ .external_name = symbol_name } } });

    // Return value in X0 (AAPCS64 convention)
    return lower_mod.ValueRegs.one(Reg.gpr(0));
}

pub fn aarch64_call_indirect(sig_ref: SigRef, ptr: lower_mod.Value, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    // Validate signature if available
    if (ctx.getSig(sig_ref)) |sig| {
        // Check argument count matches
        if (args.len != sig.params.items.len) {
            std.log.err("Call_indirect argument count mismatch: got {}, expected {}", .{ args.len, sig.params.items.len });
            return error.SignatureArgumentCountMismatch;
        }

        // Check argument types match
        for (args, 0..) |arg_value, i| {
            const arg_type = ctx.func.dfg.valueType(arg_value);
            const param_type = sig.params.items[i].value_type;
            if (!arg_type.eq(param_type)) {
                std.log.err("Call_indirect argument {} type mismatch: got {}, expected {}", .{ i, arg_type, param_type });
                return error.SignatureArgumentTypeMismatch;
            }
        }
    }

    // AAPCS64 calling convention:
    // - First 8 integer args in X0-X7
    // - First 8 FP args in V0-V7
    // - Remaining args on stack (8-byte aligned, pushed in order)

    // Get function pointer into a temporary register (not X0-X7 to avoid conflicts)
    // Use X9 as temp (caller-saved, safe to use)
    const ptr_reg = try ctx.getValueReg(ptr, .int);
    const temp_ptr = Reg.gpr(9); // X9
    if (!ptr_reg.toReg().eq(temp_ptr)) {
        try ctx.emit(Inst{ .mov_rr = .{
            .dst = lower_mod.WritableReg.fromReg(temp_ptr),
            .src = ptr_reg.toReg(),
            .size = .size64,
        } });
    }

    // Marshal arguments to ABI registers and stack
    var int_count: u32 = 0;
    var fp_count: u32 = 0;
    var stack_offset: u32 = 0;

    for (args) |arg_value| {
        const arg_type = ctx.func.dfg.valueType(arg_value);
        const is_fp = arg_type.isFloat() or arg_type.isVector();

        if (is_fp) {
            if (fp_count < 8) {
                // FP/SIMD args in V0-V7
                const arg_reg = try ctx.getValueReg(arg_value, .float);
                const abi_reg_num: u8 = @intCast(fp_count);
                const abi_reg = Reg.fpr(abi_reg_num);

                // Emit move to ABI register if not already there
                if (!arg_reg.toReg().eq(abi_reg)) {
                    try ctx.emit(Inst{ .fmov_rr = .{
                        .dst = lower_mod.WritableReg.fromReg(abi_reg),
                        .src = arg_reg.toReg(),
                        .size = typeToFpuOperandSize(arg_type),
                    } });
                }
                fp_count += 1;
            } else {
                // FP args beyond V7 go on stack
                const arg_reg = try ctx.getValueReg(arg_value, .float);
                try ctx.emit(Inst{
                    .str_fp = .{
                        .src = arg_reg.toReg(),
                        .base = Reg.gpr(31), // SP
                        .offset = @intCast(stack_offset),
                        .size = typeToFpuOperandSize(arg_type),
                    },
                });
                stack_offset += 8;
            }
        } else {
            if (int_count < 8) {
                // Integer args in X0-X7
                const arg_reg = try ctx.getValueReg(arg_value, .int);
                const abi_reg_num: u8 = @intCast(int_count);
                const abi_reg = Reg.gpr(abi_reg_num);

                // Emit move to ABI register if not already there
                if (!arg_reg.toReg().eq(abi_reg)) {
                    try ctx.emit(Inst{ .mov_rr = .{
                        .dst = lower_mod.WritableReg.fromReg(abi_reg),
                        .src = arg_reg.toReg(),
                        .size = .size64,
                    } });
                }
                int_count += 1;
            } else {
                // Integer args beyond X7 go on stack
                const arg_reg = try ctx.getValueReg(arg_value, .int);
                try ctx.emit(Inst{
                    .str = .{
                        .src = arg_reg.toReg(),
                        .base = Reg.gpr(31), // SP
                        .offset = @intCast(stack_offset),
                        .size = .size64,
                    },
                });
                stack_offset += 8;
            }
        }
    }

    // Indirect call: BLR (branch with link to register)
    try ctx.emit(Inst{ .blr = .{ .target = temp_ptr } });

    // Return value in X0 (AAPCS64 convention)
    return lower_mod.ValueRegs.one(Reg.gpr(0));
}

pub fn aarch64_try_call(sig_ref: SigRef, name: ExternalName, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    // Function call with exception handling support
    // For now, uses same ABI marshaling as regular call
    // TODO: Wire exception edge to landing pad block when available

    // Delegate to regular call implementation
    return aarch64_call(sig_ref, name, args, ctx);
}

pub fn aarch64_try_call_indirect(sig_ref: SigRef, ptr: lower_mod.Value, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    // Indirect call with exception handling support
    // For now, uses same ABI marshaling as regular indirect call
    // TODO: Wire exception edge to landing pad block when available

    // Delegate to regular indirect call implementation
    return aarch64_call_indirect(sig_ref, ptr, args, ctx);
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

/// Helper: Check if bytes form a valid lane index
fn shuffleImmAsLeLaneIdx(size: u8, bytes: []const u8) ?u8 {
    if (bytes.len != size) return null;

    // First index must be aligned to size boundary
    if (bytes[0] % size != 0) return null;

    // Bytes must be contiguous (little-endian lane)
    var i: u8 = 0;
    while (i < size - 1) : (i += 1) {
        if (bytes[i] +% 1 != bytes[i + 1]) return null;
    }

    return bytes[0] / size;
}

/// shuffle32_from_imm - Extract four 32-bit lane indices from shuffle mask
pub fn shuffle32_from_imm(imm: u128) ?struct { u8, u8, u8, u8 } {
    var bytes: [16]u8 = undefined;
    var i: u8 = 0;
    while (i < 16) : (i += 1) {
        bytes[i] = @truncate(imm >> (@as(u7, i) * 8));
    }

    const a = shuffleImmAsLeLaneIdx(4, bytes[0..4]) orelse return null;
    const b = shuffleImmAsLeLaneIdx(4, bytes[4..8]) orelse return null;
    const c = shuffleImmAsLeLaneIdx(4, bytes[8..12]) orelse return null;
    const d = shuffleImmAsLeLaneIdx(4, bytes[12..16]) orelse return null;

    return .{ a, b, c, d };
}

/// shuffle64_from_imm - Extract two 64-bit lane indices from shuffle mask
pub fn shuffle64_from_imm(imm: u128) ?struct { u8, u8 } {
    var bytes: [16]u8 = undefined;
    var i: u8 = 0;
    while (i < 16) : (i += 1) {
        bytes[i] = @truncate(imm >> (@as(u7, i) * 8));
    }

    const a = shuffleImmAsLeLaneIdx(8, bytes[0..8]) orelse return null;
    const b = shuffleImmAsLeLaneIdx(8, bytes[8..16]) orelse return null;

    return .{ a, b };
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

/// FMA constructors (ISLE constructors)
/// vec_rrr_mod: Vector FMA register-register form
/// Emits FMLA/FMLS: dst = addend + (multiplicand1 * multiplicand2)
pub fn vec_rrr_mod(
    op: VecALUModOp,
    addend: lower_mod.Value,
    multiplicand1: lower_mod.Value,
    multiplicand2: lower_mod.Value,
    size_enum: VectorSize,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.Value {
    const addend_reg = try ctx.getValueReg(addend, .vector);
    const mul1_reg = try ctx.getValueReg(multiplicand1, .vector);
    const mul2_reg = try ctx.getValueReg(multiplicand2, .vector);

    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    // Convert ISLE VectorSize to inst.VectorSize
    const size: Inst.VectorSize = switch (size_enum) {
        .V8B => .V8B,
        .V16B => .V16B,
        .V4H => .V4H,
        .V8H => .V8H,
        .V2S => .V2S,
        .V4S => .V4S,
        .V2D => .V2D,
    };

    // Convert ISLE VecALUModOp to inst.VecALUModOp
    const inst_op: Inst.VecALUModOp = switch (op) {
        .Fmla => .Fmla,
        .Fmls => .Fmls,
    };

    try ctx.emit(Inst{ .vec_rrr_mod = .{
        .op = inst_op,
        .dst = dst,
        .ri = addend_reg,
        .rn = mul1_reg,
        .rm = mul2_reg,
        .size = size,
    } });

    return ctx.getValueFromReg(dst.toReg(), .vector);
}

/// vec_rrr: Binary vector operation (VecRRR - 3 registers)
/// Emits vector ALU operation: dst = op(src1, src2)
pub fn vec_rrr(
    op: VecALUOp,
    src1: lower_mod.Value,
    src2: lower_mod.Value,
    size_enum: VectorSize,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.Value {
    const src1_reg = try ctx.getValueReg(src1, .vector);
    const src2_reg = try ctx.getValueReg(src2, .vector);
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    const size: Inst.VectorSize = switch (size_enum) {
        .V8B => .V8B,
        .V16B => .V16B,
        .V4H => .V4H,
        .V8H => .V8H,
        .V2S => .V2S,
        .V4S => .V4S,
        .V2D => .V2D,
    };

    const inst_op: Inst.VecALUOp = switch (op) {
        .Sqadd => .Sqadd,
        .Uqadd => .Uqadd,
        .Sqsub => .Sqsub,
        .Uqsub => .Uqsub,
        .Cmeq => .Cmeq,
        .Cmge => .Cmge,
        .Cmgt => .Cmgt,
        .Cmhs => .Cmhs,
        .Cmhi => .Cmhi,
        .Fcmeq => .Fcmeq,
        .Fcmgt => .Fcmgt,
        .Fcmge => .Fcmge,
        .And => .And,
        .Bic => .Bic,
        .Orr => .Orr,
        .Orn => .Orn,
        .Eor => .Eor,
        .Add => .Add,
        .Sub => .Sub,
        .Mul => .Mul,
        .Sshl => .Sshl,
        .Ushl => .Ushl,
        .Umin => .Umin,
        .Smin => .Smin,
        .Umax => .Umax,
        .Smax => .Smax,
        .Umaxp => .Umaxp,
        .Urhadd => .Urhadd,
        .Fadd => .Fadd,
        .Fsub => .Fsub,
        .Fdiv => .Fdiv,
        .Fmax => .Fmax,
        .Fmin => .Fmin,
        .Fmul => .Fmul,
        .Addp => .Addp,
        .Zip1 => .Zip1,
        .Zip2 => .Zip2,
        .Uzp1 => .Uzp1,
        .Uzp2 => .Uzp2,
        .Trn1 => .Trn1,
        .Trn2 => .Trn2,
        .Sqrdmulh => .Sqrdmulh,
    };

    try ctx.emit(Inst{ .vec_rrr = .{
        .op = inst_op,
        .dst = dst,
        .rn = src1_reg,
        .rm = src2_reg,
        .size = size,
    } });

    return ctx.getValueFromReg(dst.toReg(), .vector);
}

/// vec_misc: Unary vector operation (VecMisc - 2 registers)
/// Emits vector miscellaneous operation: dst = op(src)
pub fn vec_misc(
    op: VecMisc2,
    src: lower_mod.Value,
    size_enum: VectorSize,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.Value {
    const src_reg = try ctx.getValueReg(src, .vector);
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    const size: Inst.VectorSize = switch (size_enum) {
        .V8B => .V8B,
        .V16B => .V16B,
        .V4H => .V4H,
        .V8H => .V8H,
        .V2S => .V2S,
        .V4S => .V4S,
        .V2D => .V2D,
    };

    const inst_op: Inst.VecMisc2 = switch (op) {
        .Not => .Not,
        .Neg => .Neg,
        .Abs => .Abs,
        .Fabs => .Fabs,
        .Fneg => .Fneg,
        .Fsqrt => .Fsqrt,
        .Rev16 => .Rev16,
        .Rev32 => .Rev32,
        .Rev64 => .Rev64,
        .Fcvtzs => .Fcvtzs,
        .Fcvtzu => .Fcvtzu,
        .Scvtf => .Scvtf,
        .Ucvtf => .Ucvtf,
        .Frintn => .Frintn,
        .Frintz => .Frintz,
        .Frintm => .Frintm,
        .Frintp => .Frintp,
        .Cnt => .Cnt,
        .Cmeq0 => .Cmeq0,
        .Cmge0 => .Cmge0,
        .Cmgt0 => .Cmgt0,
        .Cmle0 => .Cmle0,
        .Cmlt0 => .Cmlt0,
        .Fcmeq0 => .Fcmeq0,
        .Fcmge0 => .Fcmge0,
        .Fcmgt0 => .Fcmgt0,
        .Fcmle0 => .Fcmle0,
        .Fcmlt0 => .Fcmlt0,
    };

    try ctx.emit(Inst{ .vec_misc = .{
        .op = inst_op,
        .dst = dst,
        .rn = src_reg,
        .size = size,
    } });

    return ctx.getValueFromReg(dst.toReg(), .vector);
}

/// vec_fmla_elem: Vector FMA element-indexed form
/// Emits FMLA/FMLS with element index: dst = addend + (multiplicand1 * multiplicand2[idx])
pub fn vec_fmla_elem(
    op: VecALUModOp,
    addend: lower_mod.Value,
    multiplicand1: lower_mod.Value,
    multiplicand2: lower_mod.Value,
    size_enum: VectorSize,
    idx: u8,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.Value {
    const addend_reg = try ctx.getValueReg(addend, .vector);
    const mul1_reg = try ctx.getValueReg(multiplicand1, .vector);
    const mul2_reg = try ctx.getValueReg(multiplicand2, .vector);

    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    // Convert ISLE VectorSize to inst.VectorSize
    const size: Inst.VectorSize = switch (size_enum) {
        .V8B => .V8B,
        .V16B => .V16B,
        .V4H => .V4H,
        .V8H => .V8H,
        .V2S => .V2S,
        .V4S => .V4S,
        .V2D => .V2D,
    };

    // Convert ISLE VecALUModOp to inst.VecALUModOp
    const inst_op: Inst.VecALUModOp = switch (op) {
        .Fmla => .Fmla,
        .Fmls => .Fmls,
    };

    try ctx.emit(Inst{ .vec_fmla_elem = .{
        .op = inst_op,
        .dst = dst,
        .ri = addend_reg,
        .rn = mul1_reg,
        .rm = mul2_reg,
        .size = size,
        .idx = idx,
    } });

    return ctx.getValueFromReg(dst.toReg(), .vector);
}

/// float_cc_cmp_zero_to_vec_misc_op: Map FloatCC to VecMisc2 for zero comparison
pub fn float_cc_cmp_zero_to_vec_misc_op(cond: FloatCC) VecMisc2 {
    return switch (cond) {
        .eq => .Fcmeq0,
        .ge => .Fcmge0,
        .le => .Fcmle0,
        .gt => .Fcmgt0,
        .lt => .Fcmlt0,
        else => unreachable, // Other FloatCC values not valid for zero comparison
    };
}

/// float_cc_cmp_zero_to_vec_misc_op_swap: Map FloatCC to VecMisc2 for swapped zero comparison
pub fn float_cc_cmp_zero_to_vec_misc_op_swap(cond: FloatCC) VecMisc2 {
    return switch (cond) {
        .eq => .Fcmeq0,
        .ge => .Fcmle0, // x >= 0 becomes 0 >= x (le)
        .le => .Fcmge0, // x <= 0 becomes 0 <= x (ge)
        .gt => .Fcmlt0, // x > 0 becomes 0 > x (lt)
        .lt => .Fcmgt0, // x < 0 becomes 0 < x (gt)
        else => unreachable,
    };
}

/// int_cc_cmp_zero_to_vec_misc_op: Map IntCC to VecMisc2 for zero comparison
pub fn int_cc_cmp_zero_to_vec_misc_op(cond: IntCC) VecMisc2 {
    return switch (cond) {
        .eq => .Cmeq0,
        .sge => .Cmge0,
        .sle => .Cmle0,
        .sgt => .Cmgt0,
        .slt => .Cmlt0,
        else => unreachable, // Other IntCC values not valid for zero comparison
    };
}

/// int_cc_cmp_zero_to_vec_misc_op_swap: Map IntCC to VecMisc2 for swapped zero comparison
pub fn int_cc_cmp_zero_to_vec_misc_op_swap(cond: IntCC) VecMisc2 {
    return switch (cond) {
        .eq => .Cmeq0,
        .sge => .Cmle0, // x >= 0 becomes 0 >= x (le)
        .sle => .Cmge0, // x <= 0 becomes 0 <= x (ge)
        .sgt => .Cmlt0, // x > 0 becomes 0 > x (lt)
        .slt => .Cmgt0, // x < 0 becomes 0 < x (gt)
        else => unreachable,
    };
}

/// fcmp_zero_cond: Extractor for valid fcmp zero conditions (not NotEqual)
pub fn fcmp_zero_cond(cond: FloatCC) ?FloatCC {
    return switch (cond) {
        .eq, .ge, .gt, .le, .lt => cond,
        else => null,
    };
}

/// fcmp_zero_cond_not_eq: Extractor for fcmp NotEqual condition
pub fn fcmp_zero_cond_not_eq(cond: FloatCC) ?FloatCC {
    return switch (cond) {
        .ne => .ne,
        else => null,
    };
}

/// icmp_zero_cond: Extractor for valid icmp zero conditions (not NotEqual)
pub fn icmp_zero_cond(cond: IntCC) ?IntCC {
    return switch (cond) {
        .eq, .sge, .sgt, .sle, .slt => cond,
        else => null,
    };
}

/// icmp_zero_cond_not_eq: Extractor for icmp NotEqual condition
pub fn icmp_zero_cond_not_eq(cond: IntCC) ?IntCC {
    return switch (cond) {
        .ne => .ne,
        else => null,
    };
}

// ============================================================================
// Helpers for lower_select
// ============================================================================

/// ty_scalar_float: Extractor for scalar float types
pub fn ty_scalar_float(ty: Type) ?Type {
    if (ty.isFloat() and !ty.isVector()) {
        return ty;
    }
    return null;
}

/// fpu_csel: FPU conditional select for F32/F64
pub fn fpu_csel(
    ty: Type,
    cond: IntCC,
    rn: lower_mod.Value,
    rm: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ConsumesFlags {
    const rn_reg = try ctx.getValueReg(rn, .float);
    const rm_reg = try ctx.getValueReg(rm, .float);
    const dst = lower_mod.WritableVReg.allocVReg(.float, ctx);

    const aarch_cond = intccToCondCode(cond);

    const size: Inst.ScalarSize = if (ty.eql(Type.f32()))
        .Size32
    else
        .Size64;

    return lower_mod.ConsumesFlags.consumesFlagsReturnsReg(
        Inst.FpuCSel{ .size = size, .rd = dst, .cond = aarch_cond, .rn = rn_reg, .rm = rm_reg },
        dst.toReg(),
    );
}

/// vec_csel: Vector conditional select for 128-bit vectors
pub fn vec_csel(
    cond: IntCC,
    rn: lower_mod.Value,
    rm: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ConsumesFlags {
    const rn_reg = try ctx.getValueReg(rn, .vector);
    const rm_reg = try ctx.getValueReg(rm, .vector);
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    const aarch_cond = intccToCondCode(cond);

    return lower_mod.ConsumesFlags.consumesFlagsReturnsReg(
        Inst.VecCSel{ .rd = dst, .cond = aarch_cond, .rn = rn_reg, .rm = rm_reg },
        dst.toReg(),
    );
}

/// put_in_regs: Convert Value to ValueRegs
pub fn put_in_regs(
    val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const ty = ctx.getValueType(val);

    if (ty.eql(Type.i128())) {
        // For I128, split into two I64 registers
        const regs = try ctx.getValueRegs(val);
        return regs;
    } else {
        // For other types, single register
        const reg = try ctx.getValueReg(val, .int);
        return lower_mod.ValueRegs.one(reg);
    }
}

/// value_regs_get: Extract register from ValueRegs at index
pub fn value_regs_get(regs: lower_mod.ValueRegs, idx: u8) Reg {
    return regs.get(idx);
}

/// consumes_flags_two_csel: Consume flags with two CSELs for I128
pub fn consumes_flags_two_csel(
    cond: IntCC,
    rn_lo: Reg,
    rn_hi: Reg,
    rm_lo: Reg,
    rm_hi: Reg,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ConsumesFlags {
    const dst_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    const dst_hi = lower_mod.WritableReg.allocReg(.int, ctx);

    const aarch_cond = intccToCondCode(cond);

    return lower_mod.ConsumesFlags.consumesFlagsTwiceReturnsValueRegs(
        Inst.CSel{ .rd = dst_lo, .cond = aarch_cond, .rn = rn_lo, .rm = rm_lo },
        Inst.CSel{ .rd = dst_hi, .cond = aarch_cond, .rn = rn_hi, .rm = rm_hi },
        lower_mod.ValueRegs.two(dst_lo.toReg(), dst_hi.toReg()),
    );
}

// ============================================================================
// Helpers for type-specific select lowering
// ============================================================================

/// fits_in_32: Extractor for types that fit in 32 bits
pub fn fits_in_32(ty: Type) ?Type {
    if (ty.bits() <= 32) {
        return ty;
    }
    return null;
}

/// put_in_reg_zext32: Put value in register with 32-bit zero extension
pub fn put_in_reg_zext32(
    val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Reg {
    const ty = ctx.getValueType(val);
    const reg = try ctx.getValueReg(val, .int);

    // If already 32-bit, return as-is
    if (ty.bits() == 32) {
        return reg;
    }

    // For smaller types, zero-extend to 32 bits
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst.Extend{
        .rd = dst,
        .rn = reg,
        .from_bits = @intCast(ty.bits()),
        .to_bits = 32,
        .signed = false,
    });

    return dst.toReg();
}

/// put_in_reg_zext64: Put value in register with 64-bit zero extension
/// put_in_reg_sext32: Put value in register with 32-bit sign extension
pub fn put_in_reg_sext32(
    val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Reg {
    const ty = ctx.getValueType(val);
    const reg = try ctx.getValueReg(val, .int);

    // If already 32-bit, return as-is
    if (ty.bits() == 32) {
        return reg;
    }

    // For smaller types, sign-extend to 32 bits
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst.Extend{
        .rd = dst,
        .rn = reg,
        .from_bits = @intCast(ty.bits()),
        .to_bits = 32,
        .signed = true,
    });

    return dst.toReg();
}
pub fn put_in_reg_zext64(
    val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Reg {
    const ty = ctx.getValueType(val);
    const reg = try ctx.getValueReg(val, .int);

    // If already 64-bit, return as-is
    if (ty.bits() == 64) {
        return reg;
    }

    // For smaller types, zero-extend to 64 bits
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst.Extend{
        .rd = dst,
        .rn = reg,
        .from_bits = @intCast(ty.bits()),
        .to_bits = 64,
        .signed = false,
    });

    return dst.toReg();
}

/// cmp: Compare two registers and produce flags
pub fn cmp(
    ty: Type,
    rn: Reg,
    rm: Reg,
    _: *lower_mod.LowerCtx(Inst),
) !lower_mod.ProducesFlags {
    const size: Inst.OperandSize = if (ty.bits() == 32)
        .Size32
    else
        .Size64;

    return lower_mod.ProducesFlags.producesFlagsSideEffect(
        Inst.AluRRR{
            .alu_op = .Sub,
            .size = size,
            .rd = lower_mod.WritableReg.zero(),
            .rn = rn,
            .rm = rm,
        },
    );
}

// Extending load helpers

/// Load byte (unsigned, zero-extend)
/// Constructor: Load with base register only (LDR Xt, [Xn])
pub fn aarch64_ldr(
    ty: types.Type,
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const dst = lower_mod.WritableReg.allocReg(typeToRegClass(ty), ctx);
    const size = typeToOperandSize(ty);

    return Inst{
        .ldr = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = size,
        },
    };
}

/// Constructor: Load with immediate offset (LDR Xt, [Xn, #offset])
pub fn aarch64_ldr_imm(
    ty: types.Type,
    base_val: lower_mod.Value,
    offset: i64,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(base_val, .int);
    const dst = lower_mod.WritableReg.allocReg(typeToRegClass(ty), ctx);
    const size = typeToOperandSize(ty);
    const offset_i16: i16 = @intCast(offset);

    return Inst{
        .ldr = .{
            .dst = dst,
            .base = base,
            .offset = offset_i16,
            .size = size,
        },
    };
}

/// Constructor: Load with register offset (LDR Xt, [Xn, Xm])
pub fn aarch64_ldr_reg(
    ty: types.Type,
    base_val: lower_mod.Value,
    offset_val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(base_val, .int);
    const offset = try ctx.getValueReg(offset_val, .int);
    const dst = lower_mod.WritableReg.allocReg(typeToRegClass(ty), ctx);
    const size = typeToOperandSize(ty);

    return Inst{
        .ldr_reg = .{
            .dst = dst,
            .base = base,
            .offset = offset,
            .size = size,
        },
    };
}

/// Constructor: Load with extended register offset (LDR Xt, [Xn, Wm, SXTW])
pub fn aarch64_ldr_ext(
    ty: types.Type,
    base_val: lower_mod.Value,
    offset_val: lower_mod.Value,
    extend: ExtendOp,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(base_val, .int);
    const offset = try ctx.getValueReg(offset_val, .int);
    const dst = lower_mod.WritableReg.allocReg(typeToRegClass(ty), ctx);
    const size = typeToOperandSize(ty);

    return Inst{
        .ldr_ext = .{
            .dst = dst,
            .base = base,
            .offset = offset,
            .extend = extend,
            .size = size,
        },
    };
}

/// Constructor: Load with shifted register offset (LDR Xt, [Xn, Xm, LSL #shift])
pub fn aarch64_ldr_shifted(
    ty: types.Type,
    base_val: lower_mod.Value,
    offset_val: lower_mod.Value,
    shift: i64,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(base_val, .int);
    const offset = try ctx.getValueReg(offset_val, .int);
    const dst = lower_mod.WritableReg.allocReg(typeToRegClass(ty), ctx);
    const size = typeToOperandSize(ty);
    const shift_u8: u8 = @intCast(shift);

    return Inst{
        .ldr_shifted = .{
            .dst = dst,
            .base = base,
            .offset = offset,
            .shift_op = .lsl, // Only LSL is supported for load/store addressing
            .shift_amt = shift_u8,
            .size = size,
        },
    };
}

/// Constructor: Load with pre-index (base += offset, then load)
pub fn aarch64_ldr_pre(
    ty: types.Type,
    base_val: lower_mod.Value,
    offset: i64,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(base_val, .int);
    const dst = lower_mod.WritableReg.allocReg(typeToRegClass(ty), ctx);
    const size = typeToOperandSize(ty);
    const offset_i16: i16 = @intCast(offset);

    return Inst{
        .ldr_pre = .{
            .dst = dst,
            .base = base,
            .offset = offset_i16,
            .size = size,
        },
    };
}

/// Constructor: Load with post-index (load, then base += offset)
pub fn aarch64_ldr_post(
    ty: types.Type,
    base_val: lower_mod.Value,
    offset: i64,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(base_val, .int);
    const dst = lower_mod.WritableReg.allocReg(typeToRegClass(ty), ctx);
    const size = typeToOperandSize(ty);
    const offset_i16: i16 = @intCast(offset);

    return Inst{
        .ldr_post = .{
            .dst = dst,
            .base = base,
            .offset = offset_i16,
            .size = size,
        },
    };
}

/// Constructor: uload8x8 - Load 8x8-bit, zero-extend to 8x16-bit
/// Pattern: LD1 {v.8B}, [addr] + USHLL v.8H, v.8B, #0
pub fn aarch64_uload8x8(
    addr_val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const addr = try ctx.getValueReg(addr_val, .int);
    const tmp = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    // LD1 {v.8B}, [addr] - load 8 bytes into lower 64 bits
    try ctx.emit(Inst{
        .ldr = .{
            .dst = tmp,
            .base = addr,
            .offset = 0,
            .size = .size64, // Load 64 bits (8 bytes)
        },
    });

    // USHLL v.8H, v.8B, #0 - unsigned shift left long (widen 8B -> 8H)
    return Inst{
        .vec_ushll = .{
            .dst = dst,
            .src = tmp.toVReg(),
            .shift_amt = 0,
            .size = .size8x8, // 8 bytes -> 8 halfwords
            .high = false, // Use low half of source
        },
    };
}

/// Constructor: sload8x8 - Load 8x8-bit, sign-extend to 8x16-bit
/// Pattern: LD1 {v.8B}, [addr] + SSHLL v.8H, v.8B, #0
pub fn aarch64_sload8x8(
    addr_val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const addr = try ctx.getValueReg(addr_val, .int);
    const tmp = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    // LD1 {v.8B}, [addr]
    try ctx.emit(Inst{
        .ldr = .{
            .dst = tmp,
            .base = addr,
            .offset = 0,
            .size = .size64,
        },
    });

    // SSHLL v.8H, v.8B, #0 - signed shift left long
    return Inst{
        .vec_sshll = .{
            .dst = dst,
            .src = tmp.toVReg(),
            .shift_amt = 0,
            .size = .size8x8,
            .high = false,
        },
    };
}

/// Constructor: uload16x4 - Load 4x16-bit, zero-extend to 4x32-bit
/// Pattern: LD1 {v.4H}, [addr] + USHLL v.4S, v.4H, #0
pub fn aarch64_uload16x4(
    addr_val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const addr = try ctx.getValueReg(addr_val, .int);
    const tmp = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    // LD1 {v.4H}, [addr] - load 4 halfwords (64 bits)
    try ctx.emit(Inst{
        .ldr = .{
            .dst = tmp,
            .base = addr,
            .offset = 0,
            .size = .size64,
        },
    });

    // USHLL v.4S, v.4H, #0
    return Inst{
        .vec_ushll = .{
            .dst = dst,
            .src = tmp.toVReg(),
            .shift_amt = 0,
            .size = .size16x4,
            .high = false,
        },
    };
}

/// Constructor: sload16x4 - Load 4x16-bit, sign-extend to 4x32-bit
/// Pattern: LD1 {v.4H}, [addr] + SSHLL v.4S, v.4H, #0
pub fn aarch64_sload16x4(
    addr_val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const addr = try ctx.getValueReg(addr_val, .int);
    const tmp = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    // LD1 {v.4H}, [addr]
    try ctx.emit(Inst{
        .ldr = .{
            .dst = tmp,
            .base = addr,
            .offset = 0,
            .size = .size64,
        },
    });

    // SSHLL v.4S, v.4H, #0
    return Inst{
        .vec_sshll = .{
            .dst = dst,
            .src = tmp.toVReg(),
            .shift_amt = 0,
            .size = .size16x4,
            .high = false,
        },
    };
}

/// Constructor: uload32x2 - Load 2x32-bit, zero-extend to 2x64-bit
/// Pattern: LD1 {v.2S}, [addr] + USHLL v.2D, v.2S, #0
pub fn aarch64_uload32x2(
    addr_val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const addr = try ctx.getValueReg(addr_val, .int);
    const tmp = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    // LD1 {v.2S}, [addr] - load 2 words (64 bits)
    try ctx.emit(Inst{
        .ldr = .{
            .dst = tmp,
            .base = addr,
            .offset = 0,
            .size = .size64,
        },
    });

    // USHLL v.2D, v.2S, #0
    return Inst{
        .vec_ushll = .{
            .dst = dst,
            .src = tmp.toVReg(),
            .shift_amt = 0,
            .size = .size32x2,
            .high = false,
        },
    };
}

/// Constructor: sload32x2 - Load 2x32-bit, sign-extend to 2x64-bit
/// Pattern: LD1 {v.2S}, [addr] + SSHLL v.2D, v.2S, #0
pub fn aarch64_sload32x2(
    addr_val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const addr = try ctx.getValueReg(addr_val, .int);
    const tmp = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    // LD1 {v.2S}, [addr]
    try ctx.emit(Inst{
        .ldr = .{
            .dst = tmp,
            .base = addr,
            .offset = 0,
            .size = .size64,
        },
    });

    // SSHLL v.2D, v.2S, #0
    return Inst{
        .vec_sshll = .{
            .dst = dst,
            .src = tmp.toVReg(),
            .shift_amt = 0,
            .size = .size32x2,
            .high = false,
        },
    };
}

/// Constructor: Store with base register only (STR Xt, [Xn])
/// Constructor: istore8 - Store 8-bit value (STRB)
pub fn aarch64_istore8(
    val: lower_mod.Value,
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const src = try ctx.getValueReg(val, .int);

    return Inst{
        .strb = .{
            .src = src,
            .base = base,
            .offset = 0,
        },
    };
}

/// Constructor: istore16 - Store 16-bit value (STRH)
pub fn aarch64_istore16(
    val: lower_mod.Value,
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const src = try ctx.getValueReg(val, .int);

    return Inst{
        .strh = .{
            .src = src,
            .base = base,
            .offset = 0,
        },
    };
}

/// Constructor: istore32 - Store 32-bit value (STR Wd)
pub fn aarch64_istore32(
    val: lower_mod.Value,
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const src = try ctx.getValueReg(val, .int);

    return Inst{
        .str = .{
            .src = src,
            .base = base,
            .offset = 0,
            .size = .size32, // 32-bit store
        },
    };
}

pub fn aarch64_str(
    val: lower_mod.Value,
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const src = try ctx.getValueReg(val, .int);
    const ty = ctx.valueType(val);
    const size = typeToOperandSize(ty);

    return Inst{
        .str = .{
            .src = src,
            .base = base,
            .offset = 0,
            .size = size,
        },
    };
}

/// Constructor: Store with immediate offset (STR Xt, [Xn, #offset])
pub fn aarch64_str_imm(
    val: lower_mod.Value,
    base_val: lower_mod.Value,
    offset: i64,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(base_val, .int);
    const src = try ctx.getValueReg(val, .int);
    const ty = ctx.valueType(val);
    const size = typeToOperandSize(ty);
    const offset_i16: i16 = @intCast(offset);

    return Inst{
        .str = .{
            .src = src,
            .base = base,
            .offset = offset_i16,
            .size = size,
        },
    };
}

/// Constructor: Store with register offset (STR Xt, [Xn, Xm])
pub fn aarch64_str_reg(
    val: lower_mod.Value,
    base_val: lower_mod.Value,
    offset_val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(base_val, .int);
    const offset = try ctx.getValueReg(offset_val, .int);
    const src = try ctx.getValueReg(val, .int);
    const ty = ctx.valueType(val);
    const size = typeToOperandSize(ty);

    return Inst{
        .str_reg = .{
            .src = src,
            .base = base,
            .offset = offset,
            .size = size,
        },
    };
}

/// Constructor: Store with extended register offset (STR Xt, [Xn, Wm, SXTW])
pub fn aarch64_str_ext(
    val: lower_mod.Value,
    base_val: lower_mod.Value,
    offset_val: lower_mod.Value,
    extend: ExtendOp,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(base_val, .int);
    const offset = try ctx.getValueReg(offset_val, .int);
    const src = try ctx.getValueReg(val, .int);
    const ty = ctx.valueType(val);
    const size = typeToOperandSize(ty);

    return Inst{
        .str_ext = .{
            .src = src,
            .base = base,
            .offset = offset,
            .extend = extend,
            .size = size,
        },
    };
}

/// Constructor: Store with shifted register offset (STR Xt, [Xn, Xm, LSL #shift])
pub fn aarch64_str_shifted(
    val: lower_mod.Value,
    base_val: lower_mod.Value,
    offset_val: lower_mod.Value,
    shift: i64,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(base_val, .int);
    const offset = try ctx.getValueReg(offset_val, .int);
    const src = try ctx.getValueReg(val, .int);
    const ty = ctx.valueType(val);
    const size = typeToOperandSize(ty);
    const shift_u8: u8 = @intCast(shift);

    return Inst{
        .str_shifted = .{
            .src = src,
            .base = base,
            .offset = offset,
            .shift_op = .lsl, // Only LSL is supported for load/store addressing
            .shift_amt = shift_u8,
            .size = size,
        },
    };
}

/// Constructor: Store with pre-index (base += offset, then store)
pub fn aarch64_str_pre(
    val: lower_mod.Value,
    base_val: lower_mod.Value,
    offset: i64,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(base_val, .int);
    const src = try ctx.getValueReg(val, .int);
    const ty = ctx.valueType(val);
    const size = typeToOperandSize(ty);
    const offset_i16: i16 = @intCast(offset);

    return Inst{
        .str_pre = .{
            .src = src,
            .base = base,
            .offset = offset_i16,
            .size = size,
        },
    };
}

/// Constructor: Store with post-index (store, then base += offset)
pub fn aarch64_str_post(
    val: lower_mod.Value,
    base_val: lower_mod.Value,
    offset: i64,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(base_val, .int);
    const src = try ctx.getValueReg(val, .int);
    const ty = ctx.valueType(val);
    const size = typeToOperandSize(ty);
    const offset_i16: i16 = @intCast(offset);

    return Inst{
        .str_post = .{
            .src = src,
            .base = base,
            .offset = offset_i16,
            .size = size,
        },
    };
}

/// Constructor: Vector load with base register (VLDR Vt, [Xn])
pub fn aarch64_vldr(
    ty: types.Type,
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const fp_size = typeToFpuOperandSize(ty);

    return Inst{
        .vldr = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = fp_size,
        },
    };
}

/// Constructor: Vector store with base register (VSTR Vt, [Xn])
pub fn aarch64_vstr(
    val: lower_mod.Value,
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const src = try ctx.getValueReg(val, .vector);
    const ty = ctx.valueType(val);
    const fp_size = typeToFpuOperandSize(ty);

    return Inst{
        .vstr = .{
            .src = src,
            .base = base,
            .offset = 0,
            .size = fp_size,
        },
    };
}

pub fn aarch64_uload8(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldrb = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .Size64,
        },
    };
}

/// Load halfword (unsigned, zero-extend)
pub fn aarch64_uload16(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldrh = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .Size64,
        },
    };
}

/// Load word (unsigned, zero-extend to 64)
pub fn aarch64_uload32(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldr = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .Size32, // LDR Wd auto zero-extends to 64
        },
    };
}

/// Load doubleword (64-bit)
pub fn aarch64_uload64(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldr = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .Size64,
        },
    };
}

/// Load signed byte (sign-extend to 64)
pub fn aarch64_sload8(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldrsb = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .Size64,
        },
    };
}

/// Load signed halfword (sign-extend to 64)
pub fn aarch64_sload16(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldrsh = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .Size64,
        },
    };
}

/// Load signed word (sign-extend to 64)
pub fn aarch64_sload32(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const base = try ctx.getValueReg(addr, .int);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldrsw = .{
            .dst = dst,
            .base = base,
            .offset = 0,
        },
    };
}

// Multiply overflow helpers

/// Unsigned multiply overflow for I16
/// Strategy: Zero-extend to 32-bit, multiply, compare result with itself extended
pub fn aarch64_umul_overflow_i16(
    ty: Type,
    a: lower_mod.Value,
    b: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    // Zero-extend both operands to 32-bit
    const a_ext = try put_in_reg_zext32(a, ctx);
    const b_ext = try put_in_reg_zext32(b, ctx);

    // Multiply: out = a_ext * b_ext
    const out_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .mul = .{
            .dst = out_dst,
            .src1 = a_ext,
            .src2 = b_ext,
            .size = .Size32,
        },
    });
    const out = out_dst.toReg();

    // Compare result with zero-extended version to detect overflow
    // If the high 16 bits are non-zero, we overflowed
    const cmp_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .Extend = .{
            .rd = cmp_dst,
            .rn = out,
            .from_bits = @intCast(ty.bits()),
            .to_bits = 32,
            .signed = false,
        },
    });

    // Compare out vs cmp_dst, set overflow flag if !=
    try ctx.emit(Inst{
        .AluRRR = .{
            .alu_op = .Sub,
            .size = .Size32,
            .rd = lower_mod.WritableReg.zero(),
            .rn = out,
            .rm = cmp_dst.toReg(),
        },
    });

    // Set overflow bit based on comparison
    const of_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .rd = of_dst,
            .cond = intccToCondCode(.ne),
        },
    });

    return lower_mod.ValueRegs.two(out_dst.toReg(), of_dst.toReg());
}

/// Unsigned multiply overflow for I32
/// Strategy: UMULL (multiply to 64-bit), compare with UXTW extension
pub fn aarch64_umul_overflow_i32(
    a: lower_mod.Value,
    b: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);

    // UMULL: 64-bit result from 32-bit operands
    const out_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .umull = .{
            .dst = out_dst,
            .src1 = a_reg,
            .src2 = b_reg,
        },
    });
    const out = out_dst.toReg();

    // Extend result back to see if high bits are set
    const ext_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .Extend = .{
            .rd = ext_dst,
            .rn = out,
            .from_bits = 32,
            .to_bits = 64,
            .signed = false,
        },
    });

    // Compare: if out != extended version, we overflowed
    try ctx.emit(Inst{
        .AluRRR = .{
            .alu_op = .Sub,
            .size = .Size64,
            .rd = lower_mod.WritableReg.zero(),
            .rn = out,
            .rm = ext_dst.toReg(),
        },
    });

    const of_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .rd = of_dst,
            .cond = intccToCondCode(.ne),
        },
    });

    return lower_mod.ValueRegs.two(out, of_dst.toReg());
}

/// Unsigned multiply overflow for I64
/// Strategy: MUL + UMULH, check if high bits are non-zero
pub fn aarch64_umul_overflow_i64(
    a: lower_mod.Value,
    b: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);

    // MUL: low 64 bits
    const out_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .mul = .{
            .dst = out_dst,
            .src1 = a_reg,
            .src2 = b_reg,
            .size = .Size64,
        },
    });

    // UMULH: high 64 bits
    const high_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .umulh = .{
            .dst = high_dst,
            .src1 = a_reg,
            .src2 = b_reg,
        },
    });

    // Compare high bits with 0 - if non-zero, we overflowed
    try ctx.emit(Inst{
        .cmp_imm = .{
            .size = .Size64,
            .rn = high_dst.toReg(),
            .imm = 0,
        },
    });

    const of_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .rd = of_dst,
            .cond = intccToCondCode(.ne),
        },
    });

    return lower_mod.ValueRegs.two(out_dst.toReg(), of_dst.toReg());
}

/// Signed multiply overflow for I16
/// Strategy: Sign-extend to 32-bit, multiply, compare result with itself extended
pub fn aarch64_smul_overflow_i16(
    ty: Type,
    a: lower_mod.Value,
    b: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    // Sign-extend both operands to 32-bit
    const a_ext = try put_in_reg_sext32(a, ctx);
    const b_ext = try put_in_reg_sext32(b, ctx);

    // Multiply
    const out_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .mul = .{
            .dst = out_dst,
            .src1 = a_ext,
            .src2 = b_ext,
            .size = .Size32,
        },
    });
    const out = out_dst.toReg();

    // Sign-extend result back to check for overflow
    const cmp_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .Extend = .{
            .rd = cmp_dst,
            .rn = out,
            .from_bits = @intCast(ty.bits()),
            .to_bits = 32,
            .signed = true,
        },
    });

    // Compare
    try ctx.emit(Inst{
        .AluRRR = .{
            .alu_op = .Sub,
            .size = .Size32,
            .rd = lower_mod.WritableReg.zero(),
            .rn = out,
            .rm = cmp_dst.toReg(),
        },
    });

    const of_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .rd = of_dst,
            .cond = intccToCondCode(.ne),
        },
    });

    return lower_mod.ValueRegs.two(out_dst.toReg(), of_dst.toReg());
}

/// Signed multiply overflow for I32
/// Strategy: SMULL (multiply to 64-bit), compare with SXTW extension
pub fn aarch64_smul_overflow_i32(
    a: lower_mod.Value,
    b: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);

    // SMULL: 64-bit result from signed 32-bit operands
    const out_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .smull = .{
            .dst = out_dst,
            .src1 = a_reg,
            .src2 = b_reg,
        },
    });
    const out = out_dst.toReg();

    // Sign-extend result back
    const ext_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .Extend = .{
            .rd = ext_dst,
            .rn = out,
            .from_bits = 32,
            .to_bits = 64,
            .signed = true,
        },
    });

    // Compare
    try ctx.emit(Inst{
        .AluRRR = .{
            .alu_op = .Sub,
            .size = .Size64,
            .rd = lower_mod.WritableReg.zero(),
            .rn = out,
            .rm = ext_dst.toReg(),
        },
    });

    const of_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .rd = of_dst,
            .cond = intccToCondCode(.ne),
        },
    });

    return lower_mod.ValueRegs.two(out, of_dst.toReg());
}

/// Signed multiply overflow for I64
/// Strategy: MUL + SMULH, compare high bits with sign-extended result
pub fn aarch64_smul_overflow_i64(
    a: lower_mod.Value,
    b: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);

    // MUL: low 64 bits
    const out_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .mul = .{
            .dst = out_dst,
            .src1 = a_reg,
            .src2 = b_reg,
            .size = .Size64,
        },
    });
    const out = out_dst.toReg();

    // SMULH: high 64 bits (signed)
    const high_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .smulh = .{
            .dst = high_dst,
            .src1 = a_reg,
            .src2 = b_reg,
        },
    });

    // Get sign extension of low bits (arithmetic shift right by 63)
    const sign_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .asr_imm = .{
            .dst = sign_dst,
            .src = out,
            .shift = 63,
            .size = .Size64,
        },
    });

    // Compare high bits with sign extension
    // If they differ, we overflowed
    try ctx.emit(Inst{
        .AluRRR = .{
            .alu_op = .Sub,
            .size = .Size64,
            .rd = lower_mod.WritableReg.zero(),
            .rn = high_dst.toReg(),
            .rm = sign_dst.toReg(),
        },
    });

    const of_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .rd = of_dst,
            .cond = intccToCondCode(.ne),
        },
    });

    return lower_mod.ValueRegs.two(out_dst.toReg(), of_dst.toReg());
}

// I128 bit manipulation helpers

/// Count leading zeros for I128
/// Algorithm from Cranelift:
/// clz hi_clz, hi
/// clz lo_clz, lo
/// lsr tmp, hi_clz, #6
/// madd dst_lo, lo_clz, tmp, hi_clz
/// mov dst_hi, 0
pub fn lower_clz128(
    val: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const hi = lower_mod.ValueRegs.getReg(val, 1);
    const lo = lower_mod.ValueRegs.getReg(val, 0);

    // CLZ on both halves
    const hi_clz_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .clz = .{
            .dst = hi_clz_dst,
            .src = hi,
            .size = .Size64,
        },
    });
    const hi_clz = hi_clz_dst.toReg();

    const lo_clz_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .clz = .{
            .dst = lo_clz_dst,
            .src = lo,
            .size = .Size64,
        },
    });
    const lo_clz = lo_clz_dst.toReg();

    // LSR tmp, hi_clz, #6 (shift right by 6 to get 0 or 1)
    const tmp_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .lsr_imm = .{
            .dst = tmp_dst,
            .src = hi_clz,
            .shift = 6,
            .size = .Size64,
        },
    });
    const tmp = tmp_dst.toReg();

    // MADD result, lo_clz, tmp, hi_clz
    // result = lo_clz * tmp + hi_clz
    const result_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .madd = .{
            .dst = result_dst,
            .src1 = lo_clz,
            .src2 = tmp,
            .src3 = hi_clz,
            .size = .Size64,
        },
    });

    const zero = lower_mod.WritableReg.zero().toReg();
    return lower_mod.ValueRegs.two(result_dst.toReg(), zero);
}

/// Count leading sign bits for I128
/// Complex algorithm from Cranelift - counts consecutive sign bits
pub fn lower_cls128(
    val: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = lower_mod.ValueRegs.getReg(val, 0);
    const hi = lower_mod.ValueRegs.getReg(val, 1);

    // CLS on both halves
    const lo_cls_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cls = .{
            .dst = lo_cls_dst,
            .src = lo,
            .size = .Size64,
        },
    });
    const lo_cls = lo_cls_dst.toReg();

    const hi_cls_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cls = .{
            .dst = hi_cls_dst,
            .src = hi,
            .size = .Size64,
        },
    });
    const hi_cls = hi_cls_dst.toReg();

    // EON sign_eq_eon, hi, lo (XOR with NOT)
    const sign_eq_eon_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .eon = .{
            .dst = sign_eq_eon_dst,
            .src1 = hi,
            .src2 = lo,
            .size = .Size64,
        },
    });
    const sign_eq_eon = sign_eq_eon_dst.toReg();

    // LSR sign_eq, sign_eq_eon, #63
    const sign_eq_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .lsr_imm = .{
            .dst = sign_eq_dst,
            .src = sign_eq_eon,
            .shift = 63,
            .size = .Size64,
        },
    });
    const sign_eq = sign_eq_dst.toReg();

    // MADD lo_sign_bits, lo_cls, sign_eq, sign_eq
    const lo_sign_bits_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .madd = .{
            .dst = lo_sign_bits_dst,
            .src1 = lo_cls,
            .src2 = sign_eq,
            .src3 = sign_eq,
            .size = .Size64,
        },
    });
    const lo_sign_bits = lo_sign_bits_dst.toReg();

    // CMP hi_cls, #63
    try ctx.emit(Inst{
        .cmp_imm = .{
            .size = .Size64,
            .rn = hi_cls,
            .imm = 63,
        },
    });

    // CSEL maybe_lo, lo_sign_bits, xzr, eq
    const maybe_lo_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .csel = .{
            .rd = maybe_lo_dst,
            .cond = intccToCondCode(.eq),
            .rn = lo_sign_bits,
            .rm = lower_mod.WritableReg.zero().toReg(),
        },
    });
    const maybe_lo = maybe_lo_dst.toReg();

    // ADD result, maybe_lo, hi_cls
    const result_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .add_rr = .{
            .dst = result_dst,
            .src1 = maybe_lo,
            .src2 = hi_cls,
            .size = .Size64,
        },
    });

    const zero = lower_mod.WritableReg.zero().toReg();
    return lower_mod.ValueRegs.two(result_dst.toReg(), zero);
}

/// Population count for I128
/// Move both halves to vector, use CNT, sum all bytes
pub fn lower_popcnt128(
    val: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = lower_mod.ValueRegs.getReg(val, 0);
    const hi = lower_mod.ValueRegs.getReg(val, 1);

    // Move lo to FPU (D register, lower half of Q)
    const tmp_half_dst = lower_mod.WritableReg.allocReg(.fpu, ctx);
    try ctx.emit(Inst{
        .fmov_from_gpr = .{
            .dst = tmp_half_dst,
            .src = lo,
            .size = .Size64,
        },
    });
    const tmp_half = tmp_half_dst.toReg();

    // Insert hi into upper half to make full 128-bit vector
    const tmp_dst = lower_mod.WritableReg.allocReg(.fpu, ctx);
    try ctx.emit(Inst{
        .vec_ins = .{
            .dst = tmp_dst,
            .src1 = tmp_half,
            .src2 = hi,
            .lane = 1,
            .size = .Size64x2,
        },
    });
    const tmp = tmp_dst.toReg();

    // CNT (count bits in each byte)
    const nbits_dst = lower_mod.WritableReg.allocReg(.fpu, ctx);
    try ctx.emit(Inst{
        .vec_cnt = .{
            .dst = nbits_dst,
            .src = tmp,
            .size = .Size8x16,
        },
    });
    const nbits = nbits_dst.toReg();

    // ADDV (sum all bytes across vector)
    const added_dst = lower_mod.WritableReg.allocReg(.fpu, ctx);
    try ctx.emit(Inst{
        .vec_addv = .{
            .dst = added_dst,
            .src = nbits,
            .size = .Size8x16,
        },
    });
    const added = added_dst.toReg();

    // Move result back to GPR
    const result_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .fmov_to_gpr = .{
            .dst = result_dst,
            .src = added,
            .size = .Size8,
        },
    });

    const zero = lower_mod.WritableReg.zero().toReg();
    return lower_mod.ValueRegs.two(result_dst.toReg(), zero);
}

/// Vector shift by immediate
pub fn aarch64_vec_shift_imm(
    op: Inst.VecShiftImmOp,
    imm: u8,
    src: lower_mod.Value,
    size: Inst.VectorSize,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    const src_reg = try ctx.getValueReg(src, .vec);
    const dst = lower_mod.WritableReg.allocReg(.vec, ctx);
    return Inst{
        .vec_shift_imm = .{
            .op = op,
            .dst = dst,
            .rn = src_reg,
            .size = size,
            .imm = imm,
        },
    };
}

/// Mask shift immediate to lane width
/// For vector shifts, the shift amount must be masked to lane_bits - 1
pub fn shift_masked_imm(ty: types.Type, imm: u64) u8 {
    const lane_bits = ty.laneBits();
    return @intCast((imm & (lane_bits - 1)));
}

/// Vector arithmetic operations (ISLE constructors)
/// Vector ADD: element-wise addition
pub fn aarch64_vec_add(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V8B => .size8x8,
        .V16B => .size8x16,
        .V4H => .size16x4,
        .V8H => .size16x8,
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => .size64x2,
    };

    return Inst{ .vec_add = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

/// Vector SUB: element-wise subtraction
pub fn aarch64_vec_sub(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V8B => .size8x8,
        .V16B => .size8x16,
        .V4H => .size16x4,
        .V8H => .size16x8,
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => .size64x2,
    };

    return Inst{ .vec_sub = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

/// Vector MUL: element-wise multiplication
pub fn aarch64_vec_mul(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V8B => .size8x8,
        .V16B => .size8x16,
        .V4H => .size16x4,
        .V8H => .size16x8,
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => .size64x2,
    };

    return Inst{ .vec_mul = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

/// Vector FADD: element-wise FP addition
pub fn aarch64_vec_fadd(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => .size64x2,
        else => return error.InvalidVectorSize,
    };

    return Inst{ .vec_fadd = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

/// Vector FSUB: element-wise FP subtraction
pub fn aarch64_vec_fsub(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => .size64x2,
        else => return error.InvalidVectorSize,
    };

    return Inst{ .vec_fsub = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

/// Vector FMUL: element-wise FP multiplication
pub fn aarch64_vec_fmul(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => .size64x2,
        else => return error.InvalidVectorSize,
    };

    return Inst{ .vec_fmul = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

/// Vector FDIV: element-wise FP division
pub fn aarch64_vec_fdiv(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => .size64x2,
        else => return error.InvalidVectorSize,
    };

    return Inst{ .vec_fdiv = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

pub fn aarch64_vec_smin(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = try vectorSizeToElemSize(size);

    return Inst{ .vec_smin = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

pub fn aarch64_vec_smax(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = try vectorSizeToElemSize(size);

    return Inst{ .vec_smax = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

pub fn aarch64_vec_umin(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = try vectorSizeToElemSize(size);

    return Inst{ .vec_umin = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

pub fn aarch64_vec_umax(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = try vectorSizeToElemSize(size);

    return Inst{ .vec_umax = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

pub fn aarch64_vec_fmin(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => .size64x2,
        else => return error.InvalidVectorSize,
    };

    return Inst{ .vec_fmin = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

pub fn aarch64_vec_fmax(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => .size64x2,
        else => return error.InvalidVectorSize,
    };

    return Inst{ .vec_fmax = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

/// Constructor: snarrow - Signed saturating narrow (SQXTN)
/// Narrow from 16→8, 32→16, or 64→32 with signed saturation
pub fn aarch64_snarrow(size: VectorSize, x: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = try vectorSizeToElemSize(size);

    return Inst{ .vec_sqxtn = .{
        .dst = dst,
        .src = x_reg,
        .size = elem_size,
        .high = false,
    } };
}

/// Constructor: unarrow - Signed to unsigned saturating narrow (SQXTUN)
/// Narrow from 16→8, 32→16, or 64→32 with unsigned saturation (from signed input)
pub fn aarch64_unarrow(size: VectorSize, x: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = try vectorSizeToElemSize(size);

    return Inst{ .vec_sqxtun = .{
        .dst = dst,
        .src = x_reg,
        .size = elem_size,
        .high = false,
    } };
}

/// Constructor: uunarrow - Unsigned saturating narrow (UQXTN)
/// Narrow from 16→8, 32→16, or 64→32 with unsigned saturation
pub fn aarch64_uunarrow(size: VectorSize, x: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const x_reg = try getValueReg(ctx, x);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = try vectorSizeToElemSize(size);

    return Inst{ .vec_uqxtn = .{
        .dst = dst,
        .src = x_reg,
        .size = elem_size,
        .high = false,
    } };
}

/// Constructor: get_frame_pointer - Get frame pointer (X29/FP)
pub fn aarch64_get_frame_pointer(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const fp = Reg.fromPReg(PReg.new(.int, 29)); // X29 (FP)

    return Inst{ .mov_rr = .{
        .dst = dst,
        .src = fp,
        .size = .size64,
    } };
}

/// Constructor: get_stack_pointer - Get stack pointer (SP)
pub fn aarch64_get_stack_pointer(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const sp = Reg.fromPReg(PReg.new(.int, 31)); // SP

    return Inst{ .mov_rr = .{
        .dst = dst,
        .src = sp,
        .size = .size64,
    } };
}

/// Constructor: get_return_address - Get return address (X30/LR)
pub fn aarch64_get_return_address(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const lr = Reg.fromPReg(PReg.new(.int, 30)); // X30 (LR)

    return Inst{ .mov_rr = .{
        .dst = dst,
        .src = lr,
        .size = .size64,
    } };
}

/// Constructor: aarch64_ld1r - Load single element and replicate to all lanes
/// Pattern: splat(load(addr)) -> LD1R {Vt.<T>}, [Xn]
/// This is more efficient than LDR + DUP (one instruction vs two)
pub fn aarch64_ld1r(ty: types.Type, addr: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const base_reg = try getValueReg(ctx, addr);

    // Map Type to VecElemSize for LD1R instruction
    const size: Inst.VecElemSize = switch (ty) {
        types.Type.V8x16 => .size8x16, // 16 × 8-bit elements
        types.Type.V16x8 => .size16x8, // 8 × 16-bit elements
        types.Type.V32x4 => .size32x4, // 4 × 32-bit elements
        types.Type.V64x2 => .size64x2, // 2 × 64-bit elements
        else => return error.UnsupportedType,
    };

    return Inst{ .ld1r = .{
        .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
        .base = base_reg,
        .size = size,
    } };
}

/// Floating-point constant constructors
/// Check if f32 can be encoded as FMOV immediate.
/// For now, only support exact 0.0 (most common case).
/// TODO: Support full VFPExpandImm encoding (±n/16 × 2^r).
fn canEncodeFMovImmF32(value: f32) bool {
    return value == 0.0;
}

/// Check if f64 can be encoded as FMOV immediate.
/// For now, only support exact 0.0 (most common case).
/// TODO: Support full VFPExpandImm encoding (±n/16 × 2^r).
fn canEncodeFMovImmF64(value: f64) bool {
    return value == 0.0;
}

/// Constructor: aarch64_f32const - Load 32-bit float constant
/// Uses FMOV immediate if possible, otherwise loads from constant pool
pub fn aarch64_f32const(value: f32, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Try FMOV immediate for common values
    if (canEncodeFMovImmF32(value)) {
        return Inst{ .fmov_imm = .{
            .dst = lower_mod.WritableReg.allocReg(.float, ctx),
            .imm = value,
            .size = .size32,
        } };
    }

    // Fall back to constant pool
    const bits: u32 = @bitCast(value);
    const label = try ctx.buffer.addConstant(bits, 4);
    const dst = lower_mod.WritableReg.allocReg(.float, ctx);

    // LDR Sd, [PC, #offset] - literal load from constant pool
    return Inst{ .ldr_literal = .{
        .dst = dst,
        .label = label,
        .size = .size32,
    } };
}

/// Constructor: aarch64_f64const - Load 64-bit float constant
/// Uses FMOV immediate if possible, otherwise loads from constant pool
pub fn aarch64_f64const(value: f64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Try FMOV immediate for common values
    if (canEncodeFMovImmF64(value)) {
        return Inst{ .fmov_imm = .{
            .dst = lower_mod.WritableReg.allocReg(.float, ctx),
            .imm = value,
            .size = .size64,
        } };
    }

    // Fall back to constant pool
    const bits: u64 = @bitCast(value);
    const label = try ctx.buffer.addConstant(bits, 8);
    const dst = lower_mod.WritableReg.allocReg(.float, ctx);

    // LDR Dd, [PC, #offset] - literal load from constant pool
    return Inst{ .ldr_literal = .{
        .dst = dst,
        .label = label,
        .size = .size64,
    } };
}

/// Compute NZCV value that makes the given condition fail.
/// Used for CCMP in AND patterns: if first condition fails, set flags to make second fail too.
///
/// NZCV format (4 bits): N Z C V
/// - N (Negative): bit 3
/// - Z (Zero): bit 2
/// - C (Carry): bit 1
/// - V (Overflow): bit 0
pub fn nzcv_for_ccmp_and_fail(cond: root.aarch64_inst.CondCode) u4 {
    return switch (cond) {
        // EQ (Z==1): To fail, set Z=0. Use NZCV=0b0000
        .eq => 0b0000,
        // NE (Z==0): To fail, set Z=1. Use NZCV=0b0100
        .ne => 0b0100,
        // CS/HS (C==1): To fail, set C=0. Use NZCV=0b0000
        .cs => 0b0000,
        // CC/LO (C==0): To fail, set C=1. Use NZCV=0b0010
        .cc => 0b0010,
        // MI (N==1): To fail, set N=0. Use NZCV=0b0000
        .mi => 0b0000,
        // PL (N==0): To fail, set N=1. Use NZCV=0b1000
        .pl => 0b1000,
        // VS (V==1): To fail, set V=0. Use NZCV=0b0000
        .vs => 0b0000,
        // VC (V==0): To fail, set V=1. Use NZCV=0b0001
        .vc => 0b0001,
        // HI (C==1 && Z==0): To fail, set Z=1 (or C=0). Use NZCV=0b0100
        .hi => 0b0100,
        // LS (C==0 || Z==1): To fail, set C=1 and Z=0. Use NZCV=0b0010
        .ls => 0b0010,
        // GE (N==V): To fail, set N!=V. Use NZCV=0b1000 (N=1,V=0)
        .ge => 0b1000,
        // LT (N!=V): To fail, set N==V. Use NZCV=0b0000 (N=0,V=0)
        .lt => 0b0000,
        // GT (Z==0 && N==V): To fail, set Z=1 (or N!=V). Use NZCV=0b0100
        .gt => 0b0100,
        // LE (Z==1 || N!=V): To fail, set Z=0 and N==V. Use NZCV=0b0000
        .le => 0b0000,
        // AL (always): Cannot fail, use 0b0000
        .al => 0b0000,
    };
}
