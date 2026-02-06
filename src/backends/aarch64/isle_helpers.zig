/// ISLE extractor and constructor helpers for aarch64.
/// These functions are called from ISLE-generated code via extern declarations.
const std = @import("std");
const builtin = @import("builtin");

const root_mod = @import("root");
const hoist = if (builtin.is_test)
    @import("../../root.zig")
else if (@hasDecl(root_mod, "entities"))
    root_mod
else
    @import("../../root.zig");
const isle_types = hoist.aarch64_isle_types;
const Inst = isle_types.Aarch64Inst;
const Reg = isle_types.Reg;
const PReg = hoist.machinst.PReg;
const Imm12 = hoist.aarch64_inst.Imm12;
const ImmLogic = isle_types.ImmLogic;
const ExtendOp = isle_types.ExtendOp;
const VecALUOp = isle_types.VecALUOp;
const VecMisc2 = isle_types.VecMisc2;
const OperandSize = hoist.aarch64_inst.OperandSize;
const FpuOperandSize = hoist.aarch64_inst.FpuOperandSize;
const VecElemSize = hoist.aarch64_inst.VecElemSize;
const SystemReg = hoist.aarch64_inst.SystemReg;
const lower_mod = hoist.lower;
const types = hoist.types;
const trapcode = hoist.trapcode;
const emit = @import("emit.zig");
const entities = hoist.entities;
const extfunc = hoist.extfunc;
const abi_mod = @import("abi.zig");
const mach_abi = hoist.abi;
const signature_mod = hoist.function.signature;

// Type aliases for IR types
const Type = types.Type;
const IntCC = hoist.condcodes.IntCC;
const FloatCC = hoist.condcodes.FloatCC;
const TrapCode = trapcode.TrapCode;
const StackSlot = entities.StackSlot;
const SigRef = entities.SigRef;
const ExternalName = extfunc.ExternalName;
const VectorSize = isle_types.VectorSize;
const VecALUModOp = isle_types.VecALUModOp;
const VecShiftImmOp = isle_types.VecShiftImmOp;
const SveElemSize = isle_types.SveElemSize;
const target_features = hoist.target;

// ISLE rule coverage tracking (optional, for testing)
const isle_coverage_mod = @import("isle_coverage.zig");
var global_isle_coverage: ?*isle_coverage_mod.IsleRuleCoverage = null;

/// Set the global ISLE coverage tracker (for testing).
pub fn setIsleCoverageTracker(tracker: ?*isle_coverage_mod.IsleRuleCoverage) void {
    global_isle_coverage = tracker;
}

/// Record an ISLE rule invocation (if coverage tracking is enabled).
pub fn recordRule(rule_name: []const u8) void {
    if (global_isle_coverage) |tracker| {
        tracker.record(rule_name) catch {}; // Ignore errors in coverage tracking
    }
}

/// Predicate: true if FEAT_DotProd is available for current target.
pub fn has_dotprod(ctx: *const lower_mod.LowerCtx(Inst)) bool {
    return ctx.features.has(target_features.AArch64Features.DOTPROD);
}

/// Predicate helper used in ISLE guards where a value operand is already bound.
pub fn has_dotprod_for(_: lower_mod.Value, ctx: *const lower_mod.LowerCtx(Inst)) bool {
    return has_dotprod(ctx);
}

/// Extractor: Try to extract Imm12 from u64.
/// Returns the Imm12 if the value fits, null otherwise.
pub fn imm12_from_u64(val: u64) ?Imm12 {
    return Imm12.maybeFromU64(val);
}

/// Extractor: Try to extract Imm12 from Value.
/// Returns the Imm12 if value fits in 12-bit encoding.
pub fn imm12_from_value(value: lower_mod.Value, ctx: *const lower_mod.LowerCtx(Inst)) ?Imm12 {
    const const_val = intValue(value, ctx) orelse return null;
    if (const_val < 0 or const_val > 4095) return null;
    return Imm12.maybeFromU64(@intCast(const_val));
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

fn splatLoadBase(value: lower_mod.Value, ctx: *const lower_mod.LowerCtx(Inst)) ?lower_mod.Value {
    const def = ctx.func.dfg.valueDef(value) orelse return null;
    const inst = def.inst() orelse return null;
    const inst_data = ctx.func.dfg.insts.get(inst) orelse return null;

    return switch (inst_data.*) {
        .load => |ld| blk: {
            if (ld.opcode != .load) return null;
            if (ld.offset != 0) return null;
            break :blk ld.arg;
        },
        else => null,
    };
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

/// Constructor: Create ImmLogic from u64 for given type.
pub fn imm_logic_from_u64(ty: types.Type, val: u64) ?ImmLogic {
    const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;
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
pub fn uimm16(val: i64) ?i64 {
    if (val < 0) return null;
    if (val <= 65535) return val;
    return null;
}

/// Extractor: Check if value is a valid shift amount (0-63).
/// Returns the value if valid, null otherwise.
pub fn valid_shift_imm(val: u64) ?u8 {
    if (val <= 63) return @intCast(val);
    return null;
}

/// Extractor: Extract rotl immediate and convert to rotr immediate.
/// ARM64 has ROR but not ROL, so rotl(x, k) = rotr(x, width - k).
/// Returns the rotr shift amount if valid, null otherwise.
pub fn valid_rotl_imm(ty: types.Type, k: u64) ?u8 {
    const width = ty.bits();
    if (width != 32 and width != 64) return null;
    if (k >= width) return null;
    if (k == 0) return 0;

    const w: u8 = @intCast(width);
    const kk: u8 = @intCast(k);
    return w - kk;
}

/// Extractor: Check if offset is valid for load immediate addressing.
/// AArch64 LDR has 12-bit unsigned immediate scaled by access size.
/// Returns the byte offset if valid (0-4095 scaled), null otherwise.
pub fn valid_ldr_imm_offset(ty: types.Type, offset: u64) ?i64 {
    // LDR immediate encoding: offset = imm12 * size
    // imm12 is 12-bit unsigned (0-4095)
    const size = ty.bytes();
    const max_offset = 4095 * size;

    // Offset must be aligned to access size
    if (offset % size != 0) return null;
    if (offset > max_offset) return null;

    return @intCast(offset);
}

/// Extractor: Check if offset is valid for store immediate addressing.
/// AArch64 STR has 12-bit unsigned immediate scaled by access size.
/// Returns the byte offset if valid (0-4095 scaled), null otherwise.
pub fn valid_str_imm_offset(
    val: lower_mod.Value,
    offset: u64,
    ctx: *lower_mod.LowerCtx(Inst),
) !?i64 {
    // STR immediate encoding: offset = imm12 * size
    // imm12 is 12-bit unsigned (0-4095)
    const ty = try ctx.getValueType(val);
    const size = ty.bytes();
    const max_offset = 4095 * size;

    // Offset must be aligned to access size
    if (offset % size != 0) return null;
    if (offset > max_offset) return null;

    return @intCast(offset);
}

pub fn is_ldp_valid_offset(offset1: i64, offset2: i64) bool {
    // LDP (pair load) uses a signed 7-bit immediate scaled by 8 for 64-bit regs.
    // We fuse only adjacent 8-byte loads: [base + off1] and [base + off1 + 8].
    if (offset2 != offset1 + 8) return false;
    if (@mod(offset1, 8) != 0) return false;
    const scaled = @divTrunc(offset1, 8);
    return scaled >= -64 and scaled <= 63;
}

pub fn is_stp_valid_offset(offset1: i64, offset2: i64) bool {
    // Same addressing constraints as LDP for our STP fusion.
    return is_ldp_valid_offset(offset1, offset2);
}

/// Extractor: Check if shift is valid for load (must be 0-3).
/// Returns the shift if valid, null otherwise.
pub fn valid_ldr_shift(ty: types.Type, shift: u64) ?i64 {
    _ = ty; // Type determines valid shift range
    if (shift <= 3) return @intCast(shift);
    return null;
}

/// Extractor: Check if shift is valid for store (must be 0-3).
/// Returns the shift if valid, null otherwise.
pub fn valid_str_shift(val: lower_mod.Value, shift: u64) ?i64 {
    _ = val; // Value type determines valid shift range
    if (shift <= 3) return @intCast(shift);
    return null;
}

/// Convert IntCC to aarch64 CondCode.
/// Maps IR condition codes to ARM condition codes.
pub fn intccToCondCode(cc: hoist.condcodes.IntCC) hoist.aarch64_inst.CondCode {
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
pub fn aarch64_cmp_rr(ty: hoist.types.Type, x: lower_mod.Value, y: lower_mod.Value, cc: hoist.condcodes.IntCC, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_cmp_rr");
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
pub fn aarch64_cmp_imm(ty: hoist.types.Type, x: lower_mod.Value, imm: i64, cc: hoist.condcodes.IntCC, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_cmp_imm");
    const size = typeToOperandSize(ty);
    const reg_x = try getValueReg(ctx, x);
    if (imm < 0) return error.InvalidImmediate;
    const imm12 = Imm12.maybeFromU64(@intCast(imm)) orelse return error.InvalidImmediate;
    _ = cc; // Condition code stored separately for branch
    return Inst{ .cmp_imm = .{
        .src = reg_x,
        .imm = imm12,
        .size = size,
    } };
}

/// Compare an I128 value against zero by OR-ing both lanes and comparing result to 0.
pub fn aarch64_cmp_i128_nonzero(
    x: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    recordRule("aarch64_cmp_i128_nonzero");
    const regs = try put_in_regs(x, ctx);
    const lo = regs.get(0) orelse return error.NoMatch;
    const hi = regs.get(1) orelse return error.NoMatch;

    const merged = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .orr_rr = .{
        .dst = merged,
        .src1 = lo,
        .src2 = hi,
        .size = .size64,
    } });

    return Inst{ .cmp_imm = .{
        .src = merged.toReg(),
        .imm = .{ .bits = 0, .shift12 = false },
        .size = .size64,
    } };
}

/// Constructor: Create CMN instruction (register, register).
/// CMN is an alias for ADDS with XZR as destination.
pub fn aarch64_cmn_rr(ty: hoist.types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_cmn_rr");
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
pub fn aarch64_ccmp_rr(ty: hoist.types.Type, x: lower_mod.Value, y: lower_mod.Value, nzcv: u4, cond: hoist.aarch64_inst.CondCode, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_ccmp_rr");
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
pub fn aarch64_ccmp_imm(ty: hoist.types.Type, x: lower_mod.Value, imm: u5, nzcv: u4, cond: hoist.aarch64_inst.CondCode, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_ccmp_imm");
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
pub fn aarch64_cmn_imm(ty: hoist.types.Type, x: lower_mod.Value, imm: i64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_cmn_imm");
    const size = typeToOperandSize(ty);
    const reg_x = try getValueReg(ctx, x);
    if (imm < 0 or imm > 4095) return error.InvalidImmediate;
    const imm_u16: u16 = @intCast(imm);
    return Inst{ .adds_imm = .{
        .dst = lower_mod.WritableReg.fromReg(Reg.gpr(31)),
        .src = reg_x,
        .imm = imm_u16,
        .size = size,
    } };
}

/// Constructor: Create CSEL (conditional select) with flags-producing instruction.
/// This emits the flags-producing instruction (e.g., CMP or CCMP), then emits CSEL.
/// Used for select patterns where we have a comparison and want to choose between two values.
pub fn aarch64_csel(
    ty: hoist.types.Type,
    true_val: lower_mod.Value,
    false_val: lower_mod.Value,
    flags_inst: Inst,
    cc: hoist.condcodes.IntCC,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    recordRule("aarch64_csel");
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
pub fn aarch64_tst_rr(ty: hoist.types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_tst_rr");
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
pub fn aarch64_tst_imm(ty: hoist.types.Type, x: lower_mod.Value, imm: u64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_tst_imm");
    const size = typeToOperandSize(ty);
    const reg_x = try getValueReg(ctx, x);
    const imm_logic = ImmLogic.maybeFromU64(imm, size) orelse return error.InvalidLogicalImmediate;
    return Inst{ .tst_imm = .{
        .src = reg_x,
        .imm = imm_logic,
    } };
}

/// Constructor: Create MUL instruction (register, register).
pub fn aarch64_mul_rr(ty: hoist.types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_mul_rr");
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
pub fn aarch64_sxtb(dst_ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_sxtb");
    const dst_size = typeToOperandSize(dst_ty);
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .sxtb = .{
        .dst = ctx.newTempReg(.int),
        .src = src_reg,
        .dst_size = dst_size,
    } };
}

/// Constructor: Zero-extend byte (UXTB).
pub fn aarch64_uxtb(dst_ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_uxtb");
    const dst_size = typeToOperandSize(dst_ty);
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .uxtb = .{
        .dst = ctx.newTempReg(.int),
        .src = src_reg,
        .dst_size = dst_size,
    } };
}

/// Constructor: Sign-extend halfword (SXTH).
pub fn aarch64_sxth(dst_ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_sxth");
    const dst_size = typeToOperandSize(dst_ty);
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .sxth = .{
        .dst = ctx.newTempReg(.int),
        .src = src_reg,
        .dst_size = dst_size,
    } };
}

/// Constructor: Zero-extend halfword (UXTH).
pub fn aarch64_uxth(dst_ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_uxth");
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
    recordRule("aarch64_sxtw");
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .sxtw = .{
        .dst = ctx.newTempReg(.int),
        .src = src_reg,
    } };
}

/// Constructor: Zero-extend word (UXTW).
/// Note: In ARM64, 32-bit operations zero-extend automatically.
pub fn aarch64_uxtw(src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_uxtw");
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
pub fn aarch64_ireduce(dst_ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_ireduce");
    const dst_size = typeToOperandSize(dst_ty);
    const src_reg = try getValueReg(ctx, src);
    return Inst{ .mov_rr = .{
        .dst = ctx.newTempReg(.int),
        .src = src_reg,
        .size = dst_size,
    } };
}

/// Constructor: Convert signed integer to float (SCVTF).
pub fn aarch64_scvtf(dst_ty: hoist.types.Type, src_ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_scvtf");
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
pub fn aarch64_ucvtf(dst_ty: hoist.types.Type, src_ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_ucvtf");
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
    recordRule("aarch64_fpromote");
    const src_reg = try getValueRegFloat(ctx, src);
    return Inst{ .fcvt_f32_to_f64 = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
    } };
}

/// Constructor: Float demote f64 to f32 (FCVT).
pub fn aarch64_fdemote(src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_fdemote");
    const src_reg = try getValueRegFloat(ctx, src);
    return Inst{ .fcvt_f64_to_f32 = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
    } };
}

/// Constructor: Bitcast - bitwise reinterpret between int and float (FMOV).
pub fn aarch64_bitcast(dst_ty: hoist.types.Type, src_ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_bitcast");

    const dst_is_float = dst_ty.isFloat();
    const src_is_float = src_ty.isFloat();

    if (src_is_float and !dst_is_float) {
        // Float to int: fmov wN, sN or fmov xN, dN
        const src_reg = try getValueRegFloat(ctx, src);
        const size: FpuOperandSize = if (dst_ty.bits() == 32) .size32 else .size64;
        return Inst{ .fmov_to_gpr = .{
            .dst = ctx.newTempReg(.int),
            .src = src_reg,
            .size = size,
        } };
    } else if (!src_is_float and dst_is_float) {
        // Int to float: fmov sN, wN or fmov dN, xN
        const src_reg = try getValueReg(ctx, src);
        const size: FpuOperandSize = if (src_ty.bits() == 32) .size32 else .size64;
        return Inst{ .fmov_from_gpr = .{
            .dst = ctx.newTempReg(.float),
            .src = src_reg,
            .size = size,
        } };
    } else {
        // Same type family - this shouldn't happen for bitcast
        return error.InvalidBitcast;
    }
}

/// Constructor: Bmask - convert to integer mask (CSET + NEG).
/// Non-zero -> all 1s (-1), zero -> all 0s (0)
pub fn aarch64_bmask(dst_ty: hoist.types.Type, src_ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_bmask");

    const src_reg = try getValueReg(ctx, src);
    const cmp_size = if (src_ty.bits() == 32) OperandSize.size32 else OperandSize.size64;
    const dst_size = if (dst_ty.bits() == 32) OperandSize.size32 else OperandSize.size64;

    // Emit: CMP src, #0
    const imm0 = Imm12.maybeFromU64(0) orelse return error.InvalidImmediate;
    const cmp_inst = Inst{ .cmp_imm = .{
        .src = src_reg,
        .imm = imm0,
        .size = cmp_size,
    } };
    try ctx.emit(cmp_inst);

    // Emit: CSET temp, NE (temp = src != 0 ? 1 : 0)
    const temp = ctx.newTempReg(.int);
    const cset_inst = Inst{ .cset = .{
        .dst = temp,
        .cond = .ne,
        .size = dst_size,
    } };
    try ctx.emit(cset_inst);

    // Emit: NEG dst, temp (dst = -temp = src != 0 ? -1 : 0)
    return Inst{ .neg = .{
        .dst = ctx.newTempReg(.int),
        .src = temp.toReg(),
        .size = dst_size,
    } };
}

/// Constructor: Float round to nearest (FRINTN).
pub fn aarch64_nearest(ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_nearest");
    const size = typeToFpuOperandSize(ty);
    const src_reg = try getValueRegFloat(ctx, src);
    return Inst{ .frintn = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
        .size = size,
    } };
}

/// Constructor: Float round toward zero (FRINTZ).
pub fn aarch64_trunc(ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_trunc");
    const size = typeToFpuOperandSize(ty);
    const src_reg = try getValueRegFloat(ctx, src);
    return Inst{ .frintz = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
        .size = size,
    } };
}

/// Constructor: Float round toward +infinity (FRINTP).
pub fn aarch64_ceil(ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_ceil");
    const size = typeToFpuOperandSize(ty);
    const src_reg = try getValueRegFloat(ctx, src);
    return Inst{ .frintp = .{
        .dst = ctx.newTempReg(.float),
        .src = src_reg,
        .size = size,
    } };
}

/// Constructor: Float round toward -infinity (FRINTM).
pub fn aarch64_floor(ty: hoist.types.Type, src: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_floor");
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
pub fn value_regs_from_values(lo: lower_mod.Value, hi: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    recordRule("value_regs_from_values");
    const lo_reg = try getValueReg(ctx, lo);
    const hi_reg = try getValueReg(ctx, hi);
    return lower_mod.ValueRegs.pair(lo_reg, hi_reg);
}

/// Constructor: Atomic load with acquire semantics (LDAR).
pub fn aarch64_atomic_load_acquire(ty: hoist.types.Type, addr: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_atomic_load_acquire");
    const addr_reg = try getValueReg(ctx, addr);
    const size = typeToOperandSize(ty);

    if (size == .size64) {
        return Inst{ .ldar = .{
            .dst = ctx.newTempReg(.int),
            .base = addr_reg,
            .size = size,
        } };
    } else {
        return Inst{ .ldar_w = .{
            .dst = ctx.newTempReg(.int),
            .base = addr_reg,
        } };
    }
}

/// Constructor: Atomic store with release semantics (STLR).
pub fn aarch64_atomic_store_release(ty: hoist.types.Type, addr: lower_mod.Value, val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_atomic_store_release");
    const addr_reg = try getValueReg(ctx, addr);
    const val_reg = try getValueReg(ctx, val);
    const size = typeToOperandSize(ty);

    if (size == .size64) {
        return Inst{ .stlr = .{
            .src = val_reg,
            .base = addr_reg,
            .size = size,
        } };
    } else {
        return Inst{ .stlr_w = .{
            .src = val_reg,
            .base = addr_reg,
        } };
    }
}

/// Constructor: Memory fence (DMB).
pub fn aarch64_fence(ordering: hoist.atomics.AtomicOrdering) !Inst {
    recordRule("aarch64_fence");
    const barrier = switch (ordering) {
        .seq_cst => hoist.aarch64_inst.BarrierOp.ish, // Sequential consistency: full barrier
        .release => hoist.aarch64_inst.BarrierOp.ishst, // Release: store barrier
        .acquire => hoist.aarch64_inst.BarrierOp.ishld, // Acquire: load barrier
        .acq_rel => hoist.aarch64_inst.BarrierOp.ish, // Acquire-release: full barrier
        else => return error.UnsupportedAtomicOrdering,
    };

    return Inst{ .dmb = .{ .option = barrier } };
}

/// Helper: Convert IR type to aarch64 operand size.
fn typeToOperandSize(ty: hoist.types.Type) hoist.aarch64_inst.OperandSize {
    if (ty.bits() <= 32) {
        return .size32;
    } else {
        return .size64;
    }
}

/// Helper: Convert IR type to aarch64 FPU operand size.
fn typeToFpuOperandSize(ty: hoist.types.Type) hoist.aarch64_inst.FpuOperandSize {
    if (ty.bits() <= 32) {
        return .size32;
    } else if (ty.bits() <= 64) {
        return .size64;
    } else {
        return .size128;
    }
}

/// Helper: Convert IR type to register class.
fn typeToRegClass(ty: hoist.types.Type) hoist.machinst.RegClass {
    if (ty.isVector()) {
        return .vector;
    } else if (ty.isFloat()) {
        return .float;
    } else {
        return .int;
    }
}

fn structFields(ctx: *lower_mod.LowerCtx(Inst), ty: Type) ![]const types.StructField {
    const fields = ty.getStructFields(&ctx.func.struct_store) orelse return error.MissingStructFields;
    return fields;
}

fn tySize(ctx: *lower_mod.LowerCtx(Inst), ty: Type) !u32 {
    if (ty.isStruct()) {
        return ty.structBytes(&ctx.func.struct_store) orelse return error.MissingStructSize;
    }
    return ty.bytes();
}

fn tyAlign(ctx: *lower_mod.LowerCtx(Inst), ty: Type) !u32 {
    if (ty.isStruct()) {
        const fields = try structFields(ctx, ty);
        if (fields.len == 0) return 1;
        var max_align: u32 = 1;
        for (fields) |field| {
            const field_align = try tyAlign(ctx, field.ty);
            if (field_align > max_align) max_align = field_align;
        }
        return max_align;
    }
    if (ty.isDynamicVector()) return 16;
    const size = ty.bytes();
    if (size == 0) return 1;
    return if (size > 16) 16 else size;
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

/// Helper: Get vector register for IR value.
fn getValueRegVec(ctx: *lower_mod.LowerCtx(Inst), value: lower_mod.Value) !lower_mod.Reg {
    const vreg = try ctx.getValueReg(value, .vector);
    return lower_mod.Reg.fromVReg(vreg);
}

/// Constructor: Convert F32 to I32 with saturation (FCVTZS).
pub fn aarch64_fcvtzs_32_to_32(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_fcvtzs_32_to_32");
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
    recordRule("aarch64_fcvtzs_64_to_32");
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
    recordRule("aarch64_fcvtzs_32_to_64");
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
    recordRule("aarch64_fcvtzs_64_to_64");
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
    recordRule("aarch64_fcvtzu_32_to_32");
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
    recordRule("aarch64_fcvtzu_64_to_32");
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
    recordRule("aarch64_fcvtzu_32_to_64");
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
    recordRule("aarch64_fcvtzu_64_to_64");
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

    // Valid shifted immediate
    const imm3 = imm12_from_u64(0x10000).?;
    try testing.expectEqual(@as(u16, 16), imm3.bits);
    try testing.expectEqual(true, imm3.shift12);
}

test "u8_into_imm12" {
    const testing = std.testing;

    const imm = u8_into_imm12(255);
    try testing.expectEqual(@as(u16, 255), imm.bits);
    try testing.expectEqual(false, imm.shift12);
}

test "intccToCondCode: equality conditions" {
    const testing = std.testing;

    try testing.expectEqual(hoist.aarch64_inst.CondCode.eq, intccToCondCode(.eq));
    try testing.expectEqual(hoist.aarch64_inst.CondCode.ne, intccToCondCode(.ne));
}

test "intccToCondCode: signed conditions" {
    const testing = std.testing;

    try testing.expectEqual(hoist.aarch64_inst.CondCode.lt, intccToCondCode(.slt));
    try testing.expectEqual(hoist.aarch64_inst.CondCode.ge, intccToCondCode(.sge));
    try testing.expectEqual(hoist.aarch64_inst.CondCode.gt, intccToCondCode(.sgt));
    try testing.expectEqual(hoist.aarch64_inst.CondCode.le, intccToCondCode(.sle));
}

test "intccToCondCode: unsigned conditions" {
    const testing = std.testing;

    try testing.expectEqual(hoist.aarch64_inst.CondCode.cc, intccToCondCode(.ult));
    try testing.expectEqual(hoist.aarch64_inst.CondCode.cs, intccToCondCode(.uge));
    try testing.expectEqual(hoist.aarch64_inst.CondCode.hi, intccToCondCode(.ugt));
    try testing.expectEqual(hoist.aarch64_inst.CondCode.ls, intccToCondCode(.ule));
}

test "aarch64_cmp_rr: creates compare instruction" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(testing.allocator, "test", hoist.function.signature.Signature.init(testing.allocator, .system_v));
    defer func.deinit();

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const v1 = lower_mod.Value.new(0);
    const v2 = lower_mod.Value.new(1);

    const inst = try aarch64_cmp_rr(hoist.types.Type.I64, v1, v2, .eq, &ctx);

    try testing.expectEqual(Inst.cmp_rr, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(hoist.aarch64_inst.OperandSize.size64, inst.cmp_rr.size);
}

test "aarch64_cmp_imm: creates compare immediate instruction" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(testing.allocator, "test", hoist.function.signature.Signature.init(testing.allocator, .system_v));
    defer func.deinit();

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const v1 = lower_mod.Value.new(0);

    const inst = try aarch64_cmp_imm(hoist.types.Type.I32, v1, 42, .ne, &ctx);

    try testing.expectEqual(Inst.cmp_imm, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(hoist.aarch64_inst.OperandSize.size32, inst.cmp_imm.size);
    try testing.expectEqual(@as(u64, 42), inst.cmp_imm.imm.toU64());
}

test "aarch64_cmp_i128_nonzero: merges lanes before cmp_imm" {
    const testing = std.testing;

    const sig = signature_mod.Signature.init(testing.allocator, .system_v);
    var func = try lower_mod.Function.init(testing.allocator, "test_cmp_i128_nonzero", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const lo_inst = try func.dfg.makeInst(.{ .unary_imm = .{
        .opcode = .iconst,
        .imm = .{ .value = 1 },
    } });
    try func.layout.appendInst(lo_inst, block0);
    const lo = try func.dfg.appendInstResult(lo_inst, Type.I64);

    const hi_inst = try func.dfg.makeInst(.{ .unary_imm = .{
        .opcode = .iconst,
        .imm = .{ .value = 2 },
    } });
    try func.layout.appendInst(hi_inst, block0);
    const hi = try func.dfg.appendInstResult(hi_inst, Type.I64);

    const iconcat_inst = try func.dfg.makeInst(.{ .binary = .{
        .opcode = .iconcat,
        .args = .{ lo, hi },
    } });
    try func.layout.appendInst(iconcat_inst, block0);
    const wide = try func.dfg.appendInstResult(iconcat_inst, Type.I128);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);
    try testing.expect(ctx.current_block != null);

    const inst = try aarch64_cmp_i128_nonzero(wide, &ctx);

    try testing.expectEqual(Inst.cmp_imm, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(@as(u64, 0), inst.cmp_imm.imm.toU64());
    try testing.expectEqual(hoist.aarch64_inst.OperandSize.size64, inst.cmp_imm.size);
    try testing.expect(hasInstTag(vcode.insns.items, .orr_rr));
}

test "put_in_regs: i128 block param falls back to pinned pair" {
    const testing = std.testing;

    var sig = signature_mod.Signature.init(testing.allocator, .system_v);
    try sig.params.append(testing.allocator, signature_mod.AbiParam.new(Type.I128));
    var func = try lower_mod.Function.init(testing.allocator, "test_put_in_regs_i128", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);
    const wide = try func.dfg.appendBlockParam(block0, Type.I128);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const regs = try put_in_regs(wide, &ctx);
    try testing.expectEqual(@as(usize, 2), regs.len());

    const got_lo = regs.get(0) orelse return error.TestUnexpectedResult;
    const got_hi = regs.get(1) orelse return error.TestUnexpectedResult;

    const expect_lo = lower_mod.Reg.fromVReg(
        lower_mod.VReg.new(@intCast(wide.index + lower_mod.Reg.PINNED_VREGS), .int),
    );
    const expect_hi = lower_mod.Reg.fromVReg(
        lower_mod.VReg.new(@intCast(wide.index + lower_mod.Reg.PINNED_VREGS + 1), .int),
    );

    try testing.expect(got_lo.eq(expect_lo));
    try testing.expect(got_hi.eq(expect_hi));
}

test "aarch64_isplit: i128 block param falls back to pinned pair" {
    const testing = std.testing;

    var sig = signature_mod.Signature.init(testing.allocator, .system_v);
    try sig.params.append(testing.allocator, signature_mod.AbiParam.new(Type.I128));
    var func = try lower_mod.Function.init(testing.allocator, "test_aarch64_isplit_i128", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);
    const wide = try func.dfg.appendBlockParam(block0, Type.I128);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const regs = try aarch64_isplit(wide, &ctx);
    try testing.expectEqual(@as(usize, 2), regs.len());

    const got_lo = regs.get(0) orelse return error.TestUnexpectedResult;
    const got_hi = regs.get(1) orelse return error.TestUnexpectedResult;

    const expect_lo = lower_mod.Reg.fromVReg(
        lower_mod.VReg.new(@intCast(wide.index + lower_mod.Reg.PINNED_VREGS), .int),
    );
    const expect_hi = lower_mod.Reg.fromVReg(
        lower_mod.VReg.new(@intCast(wide.index + lower_mod.Reg.PINNED_VREGS + 1), .int),
    );

    try testing.expect(got_lo.eq(expect_lo));
    try testing.expect(got_hi.eq(expect_hi));
}

fn hasInstTag(insns: []const Inst, tag: std.meta.Tag(Inst)) bool {
    for (insns) |insn| {
        if (@as(std.meta.Tag(Inst), insn) == tag) return true;
    }
    return false;
}

test "lower_iadd128 emits adds_rr and adcs sequence" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_iadd128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lhs_lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const lhs_hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const rhs_lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const rhs_hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();

    const out = try lower_iadd128(
        lower_mod.ValueRegs.pair(lhs_lo, lhs_hi),
        lower_mod.ValueRegs.pair(rhs_lo, rhs_hi),
        &ctx,
    );

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .adds_rr));
    try testing.expect(hasInstTag(vcode.insns.items, .adcs));
}

test "lower_isub128 emits subs_rr and sbcs sequence" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_isub128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lhs_lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const lhs_hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const rhs_lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const rhs_hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();

    const out = try lower_isub128(
        lower_mod.ValueRegs.pair(lhs_lo, lhs_hi),
        lower_mod.ValueRegs.pair(rhs_lo, rhs_hi),
        &ctx,
    );

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .subs_rr));
    try testing.expect(hasInstTag(vcode.insns.items, .sbcs));
}

test "lower_imul128 emits umulh mads and mul_rr sequence" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_imul128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lhs_lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const lhs_hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const rhs_lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const rhs_hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();

    const out = try lower_imul128(
        lower_mod.ValueRegs.pair(lhs_lo, lhs_hi),
        lower_mod.ValueRegs.pair(rhs_lo, rhs_hi),
        &ctx,
    );

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .umulh));
    try testing.expect(hasInstTag(vcode.insns.items, .madd));
    try testing.expect(hasInstTag(vcode.insns.items, .mul_rr));
}

test "lower_rotr128 emits variable-shift and csel sequence" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_rotr128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const amt = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();

    const out = try lower_rotr128(
        lower_mod.ValueRegs.pair(lo, hi),
        amt,
        &ctx,
    );

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .lsr_rr));
    try testing.expect(hasInstTag(vcode.insns.items, .lsl_rr));
    try testing.expect(hasInstTag(vcode.insns.items, .orr_rr));
    try testing.expect(hasInstTag(vcode.insns.items, .csel));
}

test "lower_rotl128 reuses rotr helper path" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_rotl128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const amt = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();

    const out = try lower_rotl128(
        lower_mod.ValueRegs.pair(lo, hi),
        amt,
        &ctx,
    );

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .neg));
    try testing.expect(hasInstTag(vcode.insns.items, .csel));
}

test "lower_band128 emits and_rr on both halves" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_band128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lhs_lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const lhs_hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const rhs_lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const rhs_hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();

    const out = try lower_band128(
        lower_mod.ValueRegs.pair(lhs_lo, lhs_hi),
        lower_mod.ValueRegs.pair(rhs_lo, rhs_hi),
        &ctx,
    );

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .and_rr));
}

test "lower_bor128 emits orr_rr on both halves" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_bor128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lhs_lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const lhs_hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const rhs_lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const rhs_hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();

    const out = try lower_bor128(
        lower_mod.ValueRegs.pair(lhs_lo, lhs_hi),
        lower_mod.ValueRegs.pair(rhs_lo, rhs_hi),
        &ctx,
    );

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .orr_rr));
}

test "lower_bxor128 emits eor_rr on both halves" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_bxor128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lhs_lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const lhs_hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const rhs_lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const rhs_hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();

    const out = try lower_bxor128(
        lower_mod.ValueRegs.pair(lhs_lo, lhs_hi),
        lower_mod.ValueRegs.pair(rhs_lo, rhs_hi),
        &ctx,
    );

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .eor_rr));
}

test "lower_bnot128 emits mvn_rr on both halves" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_bnot128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();

    const out = try lower_bnot128(lower_mod.ValueRegs.pair(lo, hi), &ctx);

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .mvn_rr));
}

test "lower_sextend128 emits asr_imm for high half" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_sextend128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const out = try lower_sextend128(lower_mod.ValueRegs.single(lo), &ctx);

    const out_lo = out.get(0) orelse return error.TestUnexpectedResult;
    try testing.expect(out_lo.eq(lo));
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .asr_imm));
}

test "lower_uextend128 reuses low half and zeros high half" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_uextend128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const out = try lower_uextend128(lower_mod.ValueRegs.single(lo), &ctx);

    const out_lo = out.get(0) orelse return error.TestUnexpectedResult;
    const out_hi = out.get(1) orelse return error.TestUnexpectedResult;
    try testing.expect(out_lo.eq(lo));
    try testing.expect(out_hi.eq(Reg.fromPReg(PReg.new(.int, 31))));
    try testing.expectEqual(@as(usize, 0), vcode.insns.items.len);
}

test "lower_ineg128 emits subs_rr and sbcs sequence" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_ineg128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const out = try lower_ineg128(lower_mod.ValueRegs.pair(lo, hi), &ctx);

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .subs_rr));
    try testing.expect(hasInstTag(vcode.insns.items, .sbcs));
}

test "lower_iabs128 emits asr/eor/subs/sbcs sequence" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_iabs128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const out = try lower_iabs128(lower_mod.ValueRegs.pair(lo, hi), &ctx);

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .asr_imm));
    try testing.expect(hasInstTag(vcode.insns.items, .eor_rr));
    try testing.expect(hasInstTag(vcode.insns.items, .subs_rr));
    try testing.expect(hasInstTag(vcode.insns.items, .sbcs));
}

test "lower_bitrev128 emits rbit on both halves" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_bitrev128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const out = try lower_bitrev128(lower_mod.ValueRegs.pair(lo, hi), &ctx);

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .rbit));
}

test "lower_bswap128 emits rev64 on both halves" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_bswap128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const out = try lower_bswap128(lower_mod.ValueRegs.pair(lo, hi), &ctx);

    try testing.expect(out.get(0) != null);
    try testing.expect(out.get(1) != null);
    try testing.expect(hasInstTag(vcode.insns.items, .rev64));
}

test "fpu_csel returns fcsel consumes-flags payload" {
    const testing = std.testing;

    var sig = signature_mod.Signature.init(testing.allocator, .system_v);
    try sig.params.append(testing.allocator, signature_mod.AbiParam.new(Type.F64));
    try sig.params.append(testing.allocator, signature_mod.AbiParam.new(Type.F64));
    var func = try lower_mod.Function.init(testing.allocator, "test_fpu_csel", sig);
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);
    const rn = try func.dfg.appendBlockParam(block0, Type.F64);
    const rm = try func.dfg.appendBlockParam(block0, Type.F64);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    try ctx.allocateSSAVRegs();
    _ = try ctx.startBlock(block0);

    const payload = try fpu_csel(Type.F64, .ne, rn, rm, &ctx);
    switch (payload) {
        .ConsumesFlagsReturnsReg => |p| {
            try testing.expectEqual(Inst.fcsel, @as(std.meta.Tag(Inst), p.inst));
            try testing.expectEqual(FpuOperandSize.size64, p.inst.fcsel.size);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "lower_clz128 emits clz and madd sequence" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_clz128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const out = try lower_clz128(lower_mod.ValueRegs.pair(lo, hi), &ctx);

    try testing.expect(out.get(0) != null);
    const out_hi = out.get(1) orelse return error.TestUnexpectedResult;
    try testing.expect(out_hi.eq(Reg.fromPReg(PReg.new(.int, 31))));

    try testing.expect(hasInstTag(vcode.insns.items, .clz));
    try testing.expect(hasInstTag(vcode.insns.items, .lsr_imm));
    try testing.expect(hasInstTag(vcode.insns.items, .madd));
}

test "lower_ctz128 emits rbit+clz and csel sequence" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_ctz128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const out = try lower_ctz128(lower_mod.ValueRegs.pair(lo, hi), &ctx);

    try testing.expect(out.get(0) != null);
    const out_hi = out.get(1) orelse return error.TestUnexpectedResult;
    try testing.expect(out_hi.eq(Reg.fromPReg(PReg.new(.int, 31))));

    try testing.expect(hasInstTag(vcode.insns.items, .rbit));
    try testing.expect(hasInstTag(vcode.insns.items, .clz));
    try testing.expect(hasInstTag(vcode.insns.items, .cmp_imm));
    try testing.expect(hasInstTag(vcode.insns.items, .csel));
}

test "lower_cls128 emits cls and csel sequence" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_cls128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const out = try lower_cls128(lower_mod.ValueRegs.pair(lo, hi), &ctx);

    try testing.expect(out.get(0) != null);
    const out_hi = out.get(1) orelse return error.TestUnexpectedResult;
    try testing.expect(out_hi.eq(Reg.fromPReg(PReg.new(.int, 31))));

    try testing.expect(hasInstTag(vcode.insns.items, .cls));
    try testing.expect(hasInstTag(vcode.insns.items, .eon_rr));
    try testing.expect(hasInstTag(vcode.insns.items, .csel));
}

test "lower_popcnt128 emits vector reduction sequence" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test_lower_popcnt128",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const lo = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const hi = lower_mod.WritableReg.allocReg(.int, &ctx).toReg();
    const out = try lower_popcnt128(lower_mod.ValueRegs.pair(lo, hi), &ctx);

    try testing.expect(out.get(0) != null);
    const out_hi = out.get(1) orelse return error.TestUnexpectedResult;
    try testing.expect(out_hi.eq(Reg.fromPReg(PReg.new(.int, 31))));

    try testing.expect(hasInstTag(vcode.insns.items, .fmov_from_gpr));
    try testing.expect(hasInstTag(vcode.insns.items, .vec_insert_lane));
    try testing.expect(hasInstTag(vcode.insns.items, .vec_addv));
    try testing.expect(hasInstTag(vcode.insns.items, .fmov_to_gpr));
}

test "aarch64_fcvtzs_32_trap emits traps" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const inst = try aarch64_fcvtzs_32_trap(lower_mod.Value.new(0), &ctx);
    try testing.expectEqual(Inst.fcvtzs, @as(std.meta.Tag(Inst), inst));

    var udf_count: usize = 0;
    var fcmp_count: usize = 0;
    var bcond_count: usize = 0;
    for (vcode.insns.items) |insn| {
        switch (insn) {
            .udf => udf_count += 1,
            .fcmp => fcmp_count += 1,
            .b_cond => bcond_count += 1,
            else => {},
        }
    }

    try testing.expectEqual(@as(usize, 3), udf_count);
    try testing.expectEqual(@as(usize, 3), fcmp_count);
    try testing.expectEqual(@as(usize, 3), bcond_count);

    var bcond_idx: usize = 0;
    for (vcode.insns.items) |insn| {
        if (insn == .b_cond) {
            const cond = insn.b_cond.cond;
            switch (bcond_idx) {
                0 => try testing.expectEqual(hoist.aarch64_inst.CondCode.vc, cond),
                1 => try testing.expectEqual(hoist.aarch64_inst.CondCode.ge, cond),
                2 => try testing.expectEqual(hoist.aarch64_inst.CondCode.lt, cond),
                else => unreachable,
            }
            bcond_idx += 1;
        }
    }
    try testing.expectEqual(@as(usize, 3), bcond_idx);
}

test "tls_local_exec zero offset returns mrs passthrough" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const inst = try tls_local_exec(0, &ctx);
    try testing.expectEqual(Inst.mov_rr, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.mrs, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(SystemReg.tpidr_el0, vcode.insns.items[0].mrs.sysreg);
}

test "tls_local_exec small offset returns add_imm" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const inst = try tls_local_exec(256, &ctx);
    try testing.expectEqual(Inst.add_imm, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(@as(u12, 256), inst.add_imm.imm);
    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.mrs, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(SystemReg.tpidr_el0, vcode.insns.items[0].mrs.sysreg);
}

test "tls_local_exec large offset materializes immediate register" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const inst = try tls_local_exec(0x5000, &ctx);
    try testing.expectEqual(Inst.add_rr, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(@as(usize, 2), vcode.insns.items.len);
    try testing.expectEqual(Inst.mrs, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(SystemReg.tpidr_el0, vcode.insns.items[0].mrs.sysreg);
    try testing.expectEqual(Inst.mov_imm, @as(std.meta.Tag(Inst), vcode.insns.items[1]));
    try testing.expectEqual(@as(u64, 0x5000), vcode.insns.items[1].mov_imm.imm);
}

test "aarch64_trapz emits cbnz skip and udf" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const val_data = hoist.instruction_data.InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = hoist.immediates.Imm64.new(1),
        },
    };
    const val_inst = try func.dfg.makeInst(val_data);
    const val = try func.dfg.appendInstResult(val_inst, types.Type.I32);
    try func.layout.appendInst(val_inst, block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const inst = try aarch64_trapz(val, TrapCode.integer_overflow, &ctx);
    try testing.expectEqual(Inst.udf, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.cbnz, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(@as(i32, 8), vcode.insns.items[0].cbnz.target.offset);
    try testing.expectEqual(@intFromEnum(TrapCode.integer_overflow), inst.udf.imm);
}

test "aarch64_trapnz emits cbz skip and udf" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(
        testing.allocator,
        "test",
        signature_mod.Signature.init(testing.allocator, .system_v),
    );
    defer func.deinit();

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);

    const val_data = hoist.instruction_data.InstructionData{
        .unary_imm = .{
            .opcode = .iconst,
            .imm = hoist.immediates.Imm64.new(1),
        },
    };
    const val_inst = try func.dfg.makeInst(val_data);
    const val = try func.dfg.appendInstResult(val_inst, types.Type.I32);
    try func.layout.appendInst(val_inst, block0);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    _ = try ctx.startBlock(block0);

    const inst = try aarch64_trapnz(val, TrapCode.heap_out_of_bounds, &ctx);
    try testing.expectEqual(Inst.udf, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.cbz, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(@as(i32, 8), vcode.insns.items[0].cbz.target.offset);
    try testing.expectEqual(@intFromEnum(TrapCode.heap_out_of_bounds), inst.udf.imm);
}

test "aarch64_cmn_rr: creates compare negative instruction" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(testing.allocator, "test", hoist.function.signature.Signature.init(testing.allocator, .system_v));
    defer func.deinit();

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const v1 = lower_mod.Value.new(0);
    const v2 = lower_mod.Value.new(1);

    const inst = try aarch64_cmn_rr(hoist.types.Type.I64, v1, v2, &ctx);

    try testing.expectEqual(Inst.cmn_rr, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(hoist.aarch64_inst.OperandSize.size64, inst.cmn_rr.size);
}

test "aarch64_cmn_imm: creates compare negative immediate instruction" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(testing.allocator, "test", hoist.function.signature.Signature.init(testing.allocator, .system_v));
    defer func.deinit();

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const v1 = lower_mod.Value.new(0);

    const inst = try aarch64_cmn_imm(hoist.types.Type.I32, v1, 100, &ctx);

    try testing.expectEqual(Inst.adds_imm, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(hoist.aarch64_inst.OperandSize.size32, inst.adds_imm.size);
    try testing.expectEqual(@as(u16, 100), inst.adds_imm.imm);
}

test "aarch64_tst_rr: creates test bits instruction" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(testing.allocator, "test", hoist.function.signature.Signature.init(testing.allocator, .system_v));
    defer func.deinit();

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const v1 = lower_mod.Value.new(0);
    const v2 = lower_mod.Value.new(1);

    const inst = try aarch64_tst_rr(hoist.types.Type.I64, v1, v2, &ctx);

    try testing.expectEqual(Inst.tst_rr, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(hoist.aarch64_inst.OperandSize.size64, inst.tst_rr.size);
}

test "aarch64_tst_imm: creates test bits immediate instruction" {
    const testing = std.testing;

    var func = try lower_mod.Function.init(testing.allocator, "test", hoist.function.signature.Signature.init(testing.allocator, .system_v));
    defer func.deinit();

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();

    const v1 = lower_mod.Value.new(0);

    const inst = try aarch64_tst_imm(hoist.types.Type.I64, v1, 0xFF, &ctx);

    try testing.expectEqual(Inst.tst_imm, @as(std.meta.Tag(Inst), inst));
    try testing.expectEqual(hoist.aarch64_inst.OperandSize.size64, inst.tst_imm.imm.size);
}

/// Constructor: SSHLL - Signed shift-left-long (widen and shift).
/// Widens lower or upper half of vector elements and optionally shifts left.
pub fn aarch64_sshll(val: lower_mod.Value, output_size: VecElemSize, shift_amt: u8, high: bool, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_sshll");
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
pub fn aarch64_ushll(val: lower_mod.Value, output_size: VecElemSize, shift_amt: u8, high: bool, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_ushll");
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
pub fn aarch64_sqxtn_combined(x: lower_mod.Value, y: lower_mod.Value, output_size: VecElemSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_sqxtn_combined");
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
pub fn aarch64_sqxtun_combined(x: lower_mod.Value, y: lower_mod.Value, output_size: VecElemSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_sqxtun_combined");
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
pub fn aarch64_uqxtn_combined(x: lower_mod.Value, y: lower_mod.Value, output_size: VecElemSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_uqxtn_combined");
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
    recordRule("aarch64_fcvtl");
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
    recordRule("aarch64_fcvtn_combined");
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

pub fn aarch64_fcvtn(x: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_fcvtn");
    const x_reg = try getValueReg(ctx, x);

    return Inst{ .vec_fcvtn = .{
        .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
        .src = x_reg,
        .high = false,
    } };
}

/// CLZ - Count leading zeros (32-bit)
pub fn aarch64_clz_32(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_clz_32");
    const src_reg = try getValueReg(ctx, val);

    return Inst{ .clz = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = src_reg,
        .size = .size32,
    } };
}

/// CLZ - Count leading zeros (64-bit)
pub fn aarch64_clz_64(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_clz_64");
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
    recordRule("aarch64_ctz_32");
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
    recordRule("aarch64_ctz_64");
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
    recordRule("aarch64_rbit_32");
    const src_reg = try getValueReg(ctx, val);

    return Inst{ .rbit = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = src_reg,
        .size = .size32,
    } };
}

/// RBIT - Reverse bits (64-bit)
pub fn aarch64_rbit_64(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_rbit_64");
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
    recordRule("aarch64_bswap_16");
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
    recordRule("aarch64_bswap_32");
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
    recordRule("aarch64_bswap_64");
    const src_reg = try getValueReg(ctx, val);

    return Inst{ .rev64 = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = src_reg,
    } };
}

/// FADD - Floating-point addition
pub fn aarch64_fadd(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_fadd");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    if (ty == types.Type.F32) {
        return Inst{ .fadd = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
            .size = .size32,
        } };
    } else { // F64
        return Inst{ .fadd = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
            .size = .size64,
        } };
    }
}

/// FSUB - Floating-point subtraction
pub fn aarch64_fsub(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_fsub");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    if (ty == types.Type.F32) {
        return Inst{ .fsub = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
            .size = .size32,
        } };
    } else { // F64
        return Inst{ .fsub = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
            .size = .size64,
        } };
    }
}

/// FMUL - Floating-point multiplication
pub fn aarch64_fmul(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_fmul");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    if (ty == types.Type.F32) {
        return Inst{ .fmul = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
            .size = .size32,
        } };
    } else { // F64
        return Inst{ .fmul = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
            .size = .size64,
        } };
    }
}

/// FDIV - Floating-point division
pub fn aarch64_fdiv(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_fdiv");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    if (ty == types.Type.F32) {
        return Inst{ .fdiv = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
            .size = .size32,
        } };
    } else { // F64
        return Inst{ .fdiv = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
            .size = .size64,
        } };
    }
}

/// FMIN - Floating-point minimum
pub fn aarch64_fmin(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_fmin");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    if (ty == types.Type.F32) {
        return Inst{ .fmin = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
            .size = .size32,
        } };
    } else { // F64
        return Inst{ .fmin = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
            .size = .size64,
        } };
    }
}

/// FMAX - Floating-point maximum
pub fn aarch64_fmax(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_fmax");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    if (ty == types.Type.F32) {
        return Inst{ .fmax = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
            .size = .size32,
        } };
    } else { // F64
        return Inst{ .fmax = .{
            .dst = lower_mod.WritableVReg.allocVReg(.float, ctx),
            .src1 = x_reg,
            .src2 = y_reg,
            .size = .size64,
        } };
    }
}

/// ROTL - Rotate left (register amount)
/// Implemented as rotr(x, -y) since ARM64 only has ROR
pub fn aarch64_rotl_rr(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_rotl_rr");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    const size: OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

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
    recordRule("aarch64_splat");
    const size = try tyToVecElemSize(ty);

    // Fuse splat(load [base]) into LD1R when the load has zero offset.
    if (splatLoadBase(x, ctx)) |base_val| {
        const base_reg = try getValueReg(ctx, base_val);
        return Inst{ .ld1r = .{
            .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
            .base = base_reg,
            .size = size,
        } };
    }

    const x_reg = try getValueReg(ctx, x);

    return Inst{ .vec_dup = .{
        .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
        .src = x_reg,
        .size = size,
    } };
}

/// avg_round for I64X2: ((x >> 1) + (y >> 1)) + ((x | y) & 1)
/// Implemented with shifts and OR so we avoid relying on unavailable URHADD.2D.
pub fn aarch64_avg_round_i64x2(
    x: lower_mod.Value,
    y: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    recordRule("aarch64_avg_round_i64x2");

    const x_reg = try getValueRegVec(ctx, x);
    const y_reg = try getValueRegVec(ctx, y);

    const x_half = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_shift_imm = .{
        .dst = x_half,
        .rn = x_reg,
        .imm = 1,
        .size = .size64x2,
        .op = .Ushr,
    } });

    const y_half = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_shift_imm = .{
        .dst = y_half,
        .rn = y_reg,
        .imm = 1,
        .size = .size64x2,
        .op = .Ushr,
    } });

    const halves_sum = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_add = .{
        .dst = halves_sum,
        .src1 = x_half.toReg(),
        .src2 = y_half.toReg(),
        .size = .size64x2,
    } });

    const or_xy = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_rrr = .{
        .dst = or_xy,
        .rn = x_reg,
        .rm = y_reg,
        .size = .V2D,
        .op = .Orr,
    } });

    const lsb_to_sign = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_shift_imm = .{
        .dst = lsb_to_sign,
        .rn = or_xy.toReg(),
        .imm = 63,
        .size = .size64x2,
        .op = .Shl,
    } });

    const rounding = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_shift_imm = .{
        .dst = rounding,
        .rn = lsb_to_sign.toReg(),
        .imm = 63,
        .size = .size64x2,
        .op = .Ushr,
    } });

    return Inst{ .vec_add = .{
        .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
        .src1 = halves_sum.toReg(),
        .src2 = rounding.toReg(),
        .size = .size64x2,
    } };
}

/// VEC_DUP_FROM_FPU - Duplicate vector element to all lanes (DUP Vd.T, Vn.T[lane])
pub fn vec_dup_from_fpu(src: lower_mod.Value, size_enum: VectorSize, lane: u8, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const src_reg = try getValueRegVec(ctx, src);

    // Map ISLE VectorSize enum to VecElemSize
    const size: VecElemSize = switch (size_enum) {
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
    const a_reg = try getValueRegVec(ctx, a);
    const b_reg = try getValueRegVec(ctx, b);

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

/// Map ISLE VectorSize enum to VecElemSize
fn vectorSizeToElemSize(size_enum: VectorSize) VecElemSize {
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

/// Map IR fixed vector Type to VecElemSize.
fn tyToVecElemSize(ty: Type) !VecElemSize {
    if (ty.isDynamicVector() or ty.laneCount() == 1) return error.UnsupportedType;

    const lane_bits = ty.laneBits();
    const lanes = ty.laneCount();

    if (lane_bits == 8 and lanes == 8) return .size8x8;
    if (lane_bits == 8 and lanes == 16) return .size8x16;
    if (lane_bits == 16 and lanes == 4) return .size16x4;
    if (lane_bits == 16 and lanes == 8) return .size16x8;
    if (lane_bits == 32 and lanes == 2) return .size32x2;
    if (lane_bits == 32 and lanes == 4) return .size32x4;
    if (lane_bits == 64 and lanes == 2) return .size64x2;

    return error.UnsupportedType;
}

/// VEC_UZP1 - De-interleave even lanes (UZP1 Vd, Vn, Vm)
pub fn vec_uzp1(a: lower_mod.Value, b: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try getValueRegVec(ctx, a);
    const b_reg = try getValueRegVec(ctx, b);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .uzp1 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src1 = a_reg, .src2 = b_reg, .size = size } };
}

/// VEC_UZP2 - De-interleave odd lanes (UZP2 Vd, Vn, Vm)
pub fn vec_uzp2(a: lower_mod.Value, b: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try getValueRegVec(ctx, a);
    const b_reg = try getValueRegVec(ctx, b);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .uzp2 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src1 = a_reg, .src2 = b_reg, .size = size } };
}

/// VEC_ZIP1 - Interleave low halves (ZIP1 Vd, Vn, Vm)
pub fn vec_zip1(a: lower_mod.Value, b: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try getValueRegVec(ctx, a);
    const b_reg = try getValueRegVec(ctx, b);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .zip1 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src1 = a_reg, .src2 = b_reg, .size = size } };
}

/// VEC_ZIP2 - Interleave high halves (ZIP2 Vd, Vn, Vm)
pub fn vec_zip2(a: lower_mod.Value, b: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try getValueRegVec(ctx, a);
    const b_reg = try getValueRegVec(ctx, b);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .zip2 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src1 = a_reg, .src2 = b_reg, .size = size } };
}

/// VEC_TRN1 - Transpose low halves (TRN1 Vd, Vn, Vm)
pub fn vec_trn1(a: lower_mod.Value, b: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try getValueRegVec(ctx, a);
    const b_reg = try getValueRegVec(ctx, b);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .trn1 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src1 = a_reg, .src2 = b_reg, .size = size } };
}

/// VEC_TRN2 - Transpose high halves (TRN2 Vd, Vn, Vm)
pub fn vec_trn2(a: lower_mod.Value, b: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try getValueRegVec(ctx, a);
    const b_reg = try getValueRegVec(ctx, b);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .trn2 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src1 = a_reg, .src2 = b_reg, .size = size } };
}

/// REV16 - Reverse bytes within 16-bit halfwords
pub fn rev16(a: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try getValueRegVec(ctx, a);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .vec_rev16 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src = a_reg, .size = size } };
}

/// REV32 - Reverse bytes within 32-bit words
pub fn rev32(a: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try getValueRegVec(ctx, a);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .vec_rev32 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src = a_reg, .size = size } };
}

/// REV64 - Reverse bytes within 64-bit doublewords
pub fn rev64(a: lower_mod.Value, size_enum: VectorSize, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const a_reg = try getValueRegVec(ctx, a);
    const size = vectorSizeToElemSize(size_enum);
    return Inst{ .vec_rev64 = .{ .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx), .src = a_reg, .size = size } };
}

/// EXTRACTLANE - Extract vector lane to scalar (UMOV)
pub fn aarch64_extractlane(ty: types.Type, vec: lower_mod.Value, lane: u32, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_extractlane");
    const vec_reg = try getValueRegVec(ctx, vec);
    // Some lowering paths pass vector ty, others pass scalar lane ty.
    const size = blk: {
        if (ty.isVector()) break :blk try tyToVecElemSize(ty);
        const vec_ty = try ctx.getValueType(vec);
        const vec_size = try tyToVecElemSize(vec_ty);
        if (ty.bits() != vec_size.bits()) return error.UnsupportedType;
        break :blk vec_size;
    };
    if (lane >= size.laneCount()) return error.InvalidLane;
    const lane_u8: u8 = @intCast(lane);

    return Inst{ .vec_extract_lane = .{
        .dst = lower_mod.WritableVReg.allocVReg(.int, ctx),
        .src = vec_reg,
        .lane = lane_u8,
        .size = size,
    } };
}

/// SMIN - Signed minimum (CMP + CSEL)
/// Implemented as: cmp x, y; csel result, x, y, lt
pub fn aarch64_smin(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_smin");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const size: OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

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
    recordRule("aarch64_umin");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const size: OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

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
        .cond = .cc,
        .size = size,
    } };
}

/// SMAX - Signed maximum (CMP + CSEL)
/// Implemented as: cmp x, y; csel result, x, y, gt
pub fn aarch64_smax(ty: types.Type, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_smax");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const size: OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

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
    recordRule("aarch64_umax");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const size: OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

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
    recordRule("aarch64_bitselect");
    const c_reg = try getValueReg(ctx, c);
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);

    const ty = try ctx.getValueType(x);
    const size: OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

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
    recordRule("aarch64_fcopysign_32");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const size: FpuOperandSize = .size32;

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
    recordRule("aarch64_and_imm");
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
    recordRule("aarch64_orr_imm");
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
    recordRule("aarch64_eor_imm");
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
        const int_vreg = try ctx.getValueReg(lower_mod.Value.new(0), .int); // Temp allocation
        const int_reg = Reg.fromVReg(int_vreg);
        const load_inst = Inst{ .mov_imm = .{
            .dst = lower_mod.WritableVReg.fromVReg(int_vreg),
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
        const int_vreg = try ctx.getValueReg(lower_mod.Value.new(0), .int);
        const int_reg = Reg.fromVReg(int_vreg);
        const load_inst = Inst{ .mov_imm = .{
            .dst = lower_mod.WritableVReg.fromVReg(int_vreg),
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
    const bits = ty.bits();
    return std.math.cast(u8, bits) orelse 0;
}

/// Extractor: Match vector type, return (lane_bits, lane_count)
/// Returns null for scalar types
pub fn multi_lane(ty: types.Type) ?struct { field0: u32, field1: u32 } {
    if (!ty.isVector()) return null;
    return .{ .field0 = ty.laneBits(), .field1 = ty.laneCount() };
}

test "multi_lane returns bits and lanes" {
    const OhSnap = @import("ohsnap");
    const testing = std.testing;
    const oh = OhSnap{};

    const got = multi_lane(types.Type.I8X16);
    try testing.expect(got != null);

    const Fmt = struct {
        lane: @TypeOf(got.?),

        pub fn format(self: @This(), writer: anytype) !void {
            try writer.print("{d}:{d}", .{ self.lane.field0, self.lane.field1 });
        }
    };

    try oh.snap(@src(),
        \\8:16
    ).expectEqualFmt(Fmt{ .lane = got.? });
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
    if (ty == types.Type.I64X2) {
        return null;
    }
    return ty;
}

/// Extractor: Match scalable/dynamic vector types, return SVE element size
/// Returns the SveElemSize for dynamic vector types, null for fixed-size vectors.
pub fn sve_elem_size(ty: types.Type) ?SveElemSize {
    // Check if this is a dynamic/scalable vector type
    if (!ty.isDynamicVector()) return null;

    // Get element bits from the dynamic vector type
    const lane_bits = ty.laneBits();
    return switch (lane_bits) {
        8 => .B,
        16 => .H,
        32 => .S,
        64 => .D,
        else => null,
    };
}

/// Trap operations (ISLE constructors)
pub fn aarch64_trap(trap_code: TrapCode, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_trap");
    _ = ctx;
    return Inst{ .udf = .{ .imm = @intFromEnum(trap_code) } };
}

pub fn aarch64_trapz(val: lower_mod.Value, trap_code: TrapCode, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_trapz");
    const ty = try ctx.getValueType(val);
    const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;
    const val_reg = Reg.fromVReg(try ctx.getValueReg(val, .int));

    // Skip trap if val != 0 (skip returned UDF).
    try ctx.emit(Inst{ .cbnz = .{
        .reg = val_reg,
        .target = .{ .offset = 8 },
        .size = size,
    } });

    return Inst{ .udf = .{ .imm = @intFromEnum(trap_code) } };
}

pub fn aarch64_trapnz(val: lower_mod.Value, trap_code: TrapCode, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_trapnz");
    const ty = try ctx.getValueType(val);
    const size: OperandSize = if (ty.bits() <= 32) .size32 else .size64;
    const val_reg = Reg.fromVReg(try ctx.getValueReg(val, .int));

    // Skip trap if val == 0 (skip returned UDF).
    try ctx.emit(Inst{ .cbz = .{
        .reg = val_reg,
        .target = .{ .offset = 8 },
        .size = size,
    } });

    return Inst{ .udf = .{ .imm = @intFromEnum(trap_code) } };
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
        const int_vreg = try ctx.getValueReg(lower_mod.Value.new(0), .int);
        const int_reg = Reg.fromVReg(int_vreg);
        const load_inst = Inst{ .mov_imm = .{
            .dst = lower_mod.WritableVReg.fromVReg(int_vreg),
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
        const int_vreg = try ctx.getValueReg(lower_mod.Value.new(0), .int);
        const int_reg = Reg.fromVReg(int_vreg);
        const load_inst = Inst{ .mov_imm = .{
            .dst = lower_mod.WritableVReg.fromVReg(int_vreg),
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
pub fn aarch64_fcvtzs_32_trap(x: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_fcvtzs_32_trap");
    const x_reg = try getValueRegFloat(ctx, x);

    // NaN check: FCMP x, x; if VS then trap
    try ctx.emit(Inst{ .fcmp = .{
        .src1 = x_reg,
        .src2 = x_reg,
        .size = .size32,
    } });
    try ctx.emit(Inst{ .b_cond = .{
        .cond = .vc,
        .target = .{ .offset = 4 },
    } });
    try ctx.emit(Inst{ .udf = .{ .imm = @intFromEnum(TrapCode.bad_conversion_to_integer) } });

    // Underflow check: FCMP x, min_fp_value; if GE then ok, else trap
    const min_reg = try min_fp_value(true, 32, 32, ctx);
    try ctx.emit(Inst{ .fcmp = .{
        .src1 = x_reg,
        .src2 = min_reg,
        .size = .size32,
    } });
    try ctx.emit(Inst{ .b_cond = .{
        .cond = .ge,
        .target = .{ .offset = 4 },
    } });
    try ctx.emit(Inst{ .udf = .{ .imm = @intFromEnum(TrapCode.bad_conversion_to_integer) } });

    // Overflow check: FCMP x, max_fp_value; if LT then ok, else trap
    const max_reg = try max_fp_value(true, 32, 32, ctx);
    try ctx.emit(Inst{ .fcmp = .{
        .src1 = x_reg,
        .src2 = max_reg,
        .size = .size32,
    } });
    try ctx.emit(Inst{ .b_cond = .{
        .cond = .lt,
        .target = .{ .offset = 4 },
    } });
    try ctx.emit(Inst{ .udf = .{ .imm = @intFromEnum(TrapCode.bad_conversion_to_integer) } });

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
    recordRule("aarch64_iabs");
    const x_reg = try getValueReg(ctx, x);
    const size: OperandSize = if (ty == types.Type.I32 or ty == types.Type.I16 or ty == types.Type.I8) .size32 else .size64;

    // Compare x with 0
    const cmp_inst = Inst{ .cmp_imm = .{
        .src = x_reg,
        .imm = .{ .bits = 0, .shift12 = false },
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
pub fn aarch64_insertlane(ty: types.Type, vec: lower_mod.Value, x: lower_mod.Value, lane: u32, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_insertlane");
    const vec_reg = try getValueRegVec(ctx, vec);
    const x_reg = try getValueReg(ctx, x);
    const size = try tyToVecElemSize(ty);
    if (lane >= size.laneCount()) return error.InvalidLane;
    const lane_u8: u8 = @intCast(lane);

    return Inst{ .vec_insert_lane = .{
        .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
        .vec = vec_reg,
        .src = x_reg,
        .lane = lane_u8,
        .size = size,
    } };
}

/// ISPLIT - Split I128 into low and high I64 parts
/// Returns ValueRegs containing the two 64-bit halves
pub fn aarch64_isplit(x: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    recordRule("aarch64_isplit");
    if (ctx.func.dfg.valueDef(x)) |def| {
        if (def.inst()) |inst| {
            if (ctx.func.dfg.insts.get(inst)) |inst_data_ptr| {
                switch (inst_data_ptr.*) {
                    .binary => |data| {
                        if (data.opcode == .iconcat) {
                            const lo = data.args[0];
                            const hi = data.args[1];
                            const lo_reg = try getValueReg(ctx, lo);
                            const hi_reg = try getValueReg(ctx, hi);
                            return lower_mod.ValueRegs.pair(lo_reg, hi_reg);
                        }
                    },
                    else => {},
                }
            }
        }
    }

    // Fallback mapping for non-iconcat I128 producers.
    const ty = try ctx.getValueType(x);
    if (!ty.eql(Type.I128)) {
        return error.Unimplemented;
    }

    const lo_vreg = lower_mod.VReg.new(@intCast(x.index + lower_mod.Reg.PINNED_VREGS), .int);
    const hi_vreg = lower_mod.VReg.new(@intCast(x.index + lower_mod.Reg.PINNED_VREGS + 1), .int);
    return lower_mod.ValueRegs.pair(
        lower_mod.Reg.fromVReg(lo_vreg),
        lower_mod.Reg.fromVReg(hi_vreg),
    );
}

/// Bitcast operations (ISLE constructors)
pub fn aarch64_bitcast_noop(x: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_bitcast_noop");
    // No-op bitcast in same register file: just copy into a new temp.
    const src = try getValueReg(ctx, x);
    return Inst{ .mov_rr = .{ .dst = ctx.newTempReg(.int), .src = src, .size = .size64 } };
}

pub fn aarch64_fmov_from_gpr(x: lower_mod.Value, in_ty: types.Type, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_fmov_from_gpr");
    const gpr = lower_mod.Reg.fromVReg(try ctx.getValueReg(x, .int));
    const fpr = lower_mod.WritableVReg.allocVReg(.float, ctx);
    const size: FpuOperandSize = if (in_ty.bits() == 32) .size32 else .size64;
    return Inst{ .fmov_from_gpr = .{ .dst = fpr, .src = gpr, .size = size } };
}

pub fn aarch64_fmov_to_gpr(x: lower_mod.Value, out_ty: types.Type, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_fmov_to_gpr");
    const fpr = lower_mod.Reg.fromVReg(try ctx.getValueReg(x, .float));
    const gpr = lower_mod.WritableReg.allocReg(.int, ctx);
    const size: FpuOperandSize = if (out_ty.bits() == 32) .size32 else .size64;
    return Inst{ .fmov_to_gpr = .{ .dst = gpr, .src = fpr, .size = size } };
}

/// ABI register accessors (ISLE constructors)
pub fn stack_reg(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    _ = ctx;
    // Return SP register (x31 when used as stack pointer)
    return Inst{ .mov_rr = .{ .dst = lower_mod.WritableReg.fromReg(Reg.gpr(31)), .src = Reg.gpr(31), .size = .size64 } };
}

pub fn fp_reg(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    _ = ctx;
    // Return FP register (x29 - frame pointer)
    return Inst{ .mov_rr = .{ .dst = lower_mod.WritableReg.fromReg(Reg.gpr(29)), .src = Reg.gpr(29), .size = .size64 } };
}

pub fn link_reg(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    _ = ctx;
    // Return LR register (x30 - link register)
    return Inst{ .mov_rr = .{ .dst = lower_mod.WritableReg.fromReg(Reg.gpr(30)), .src = Reg.gpr(30), .size = .size64 } };
}

pub fn aarch64_get_pinned_reg(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_get_pinned_reg");
    _ = ctx;
    const pinned = Reg.gpr(pinnedRegNum());
    return Inst{ .mov_rr = .{ .dst = lower_mod.WritableReg.fromReg(pinned), .src = pinned, .size = .size64 } };
}

pub fn aarch64_set_pinned_reg(val: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_set_pinned_reg");
    const src = try ctx.getValueReg(val, .int);
    const pinned = Reg.gpr(pinnedRegNum());
    return Inst{ .mov_rr = .{ .dst = lower_mod.WritableReg.fromReg(pinned), .src = src, .size = .size64 } };
}

fn pinnedRegNum() u6 {
    return switch (abi_mod.Platform.detect()) {
        .darwin => 18,
        .linux, .other => 28,
    };
}

/// Exception handling: landingpad reads exception value from X0
pub fn aarch64_landingpad(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_landingpad");
    // Allocate vreg for exception value
    const dst = try ctx.allocOutputReg(.int);
    // Move exception pointer from X0 (AAPCS64 exception value register)
    return Inst{ .mov_rr = .{ .dst = dst, .src = Reg.gpr(0), .size = .size64 } };
}

/// Stack switching for fiber/coroutine support (ISLE constructors)
pub fn aarch64_stack_switch(old_sp_addr: lower_mod.Value, new_sp_addr: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_stack_switch");
    // Stack switch sequence:
    // 1. ADD X<tmp>, SP, #0          - Save current SP
    // 2. STR X<tmp>, [old_sp_addr]   - Store to old_sp_addr
    // 3. LDR X<new>, [new_sp_addr]   - Load from new_sp_addr
    // 4. ADD SP, X<new>, #0          - Switch to new SP (MOV to SP alias)

    const sp = Reg.gpr(31); // SP register
    const tmp = lower_mod.WritableReg.allocReg(.int, ctx);

    // Save current SP to temporary
    try ctx.emit(Inst{
        .add_imm = .{
            .dst = tmp,
            .src = sp, // reads SP when Rn=31
            .imm = 0,
            .size = .size64,
        },
    });

    // Store old SP to memory
    const old_addr_reg = Reg.fromVReg(try ctx.getValueReg(old_sp_addr, .int));
    try ctx.emit(Inst{ .str = .{
        .src = tmp.toReg(),
        .base = old_addr_reg,
        .offset = 0,
        .size = .size64,
    } });

    // Load new SP from memory
    const new_addr_reg = Reg.fromVReg(try ctx.getValueReg(new_sp_addr, .int));
    const new_sp = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .ldr = .{
        .dst = new_sp,
        .base = new_addr_reg,
        .offset = 0,
        .size = .size64,
    } });

    // Switch to new stack pointer
    const inst = Inst{ .add_imm = .{
        .dst = lower_mod.WritableReg.fromReg(sp),
        .src = new_sp.toReg(),
        .imm = 0,
        .size = .size64,
    } };
    try ctx.emit(inst);
    return inst;
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
        .sysreg = SystemReg.tpidr_el0,
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
        .sysreg = SystemReg.tpidr_el0,
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
        .sysreg = SystemReg.tpidr_el0,
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
pub fn aarch64_dynamic_stack_addr(offset: u64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    // Get dynamic stack pointer register (X19)
    // This requires dynamic allocations to be enabled in the ABI
    const dyn_sp = Reg.gpr(19); // X19 - dynamic stack pointer
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);

    // Compute address: ADD Xd, X19, #offset
    if (offset == 0) {
        // Just move the dynamic SP
        const inst = Inst{ .mov_rr = .{
            .dst = dst,
            .src = dyn_sp,
            .size = .size64,
        } };
        try ctx.emit(inst);
        return inst;
    } else if (offset <= 0xFFF) {
        // Small offset fits in ADD immediate
        const inst = Inst{ .add_imm = .{
            .dst = dst,
            .src = dyn_sp,
            .imm = @intCast(offset),
            .size = .size64,
        } };
        try ctx.emit(inst);
        return inst;
    } else {
        // Large offset - load into register first
        const offset_reg = lower_mod.WritableReg.allocReg(.int, ctx);
        try ctx.emit(Inst{ .mov_imm = .{
            .dst = offset_reg,
            .imm = offset,
            .size = .size64,
        } });
        const inst = Inst{ .add_rr = .{
            .dst = dst,
            .src1 = dyn_sp,
            .src2 = offset_reg.toReg(),
            .size = .size64,
        } };
        try ctx.emit(inst);
        return inst;
    }
}

pub fn aarch64_dynamic_stack_load(ty: Type, offset: u64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const addr_inst = try aarch64_dynamic_stack_addr(offset, ctx);
    const addr_dst = switch (addr_inst) {
        .mov_rr => |i| i.dst,
        .add_imm => |i| i.dst,
        .add_rr => |i| i.dst,
        else => return error.UnexpectedDynStackAddrInst,
    };
    const base = addr_dst.toReg();

    const dst_class = typeToRegClass(ty);
    const dst = lower_mod.WritableReg.allocReg(dst_class, ctx);
    const bits = ty.bits();

    const inst = if (ty.isInt()) blk: {
        const size = typeToOperandSize(ty);
        if (bits == 64 or bits == 32) break :blk Inst{ .ldr = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = size,
        } };
        if (bits == 16) break :blk Inst{ .ldrh = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = size,
        } };
        if (bits == 8) break :blk Inst{ .ldrb = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = size,
        } };
        return error.UnsupportedIntegerSize;
    } else if (ty.isFloat() or ty.isVector()) blk: {
        const fp_size = typeToFpuOperandSize(ty);
        break :blk Inst{ .vldr = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = fp_size,
        } };
    } else if (ty.isDynamicVector()) {
        return error.Unimplemented;
    } else {
        return error.UnsupportedType;
    };

    try ctx.emit(inst);
    return inst;
}

pub fn aarch64_dynamic_stack_store(ty: Type, val: lower_mod.Value, offset: u64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    const addr_inst = try aarch64_dynamic_stack_addr(offset, ctx);
    const addr_dst = switch (addr_inst) {
        .mov_rr => |i| i.dst,
        .add_imm => |i| i.dst,
        .add_rr => |i| i.dst,
        else => return error.UnexpectedDynStackAddrInst,
    };
    const base = addr_dst.toReg();

    const bits = ty.bits();
    const src_class = typeToRegClass(ty);
    const src = Reg.fromVReg(try ctx.getValueReg(val, src_class));

    const inst = if (ty.isInt()) blk: {
        const size = typeToOperandSize(ty);
        if (bits == 64 or bits == 32) break :blk Inst{ .str = .{
            .src = src,
            .base = base,
            .offset = 0,
            .size = size,
        } };
        if (bits == 16) break :blk Inst{ .strh = .{
            .src = src,
            .base = base,
            .offset = 0,
        } };
        if (bits == 8) break :blk Inst{ .strb = .{
            .src = src,
            .base = base,
            .offset = 0,
        } };
        return error.UnsupportedIntegerSize;
    } else if (ty.isFloat() or ty.isVector()) blk: {
        const fp_size = typeToFpuOperandSize(ty);
        break :blk Inst{ .vstr = .{
            .src = src,
            .base = base,
            .offset = 0,
            .size = fp_size,
        } };
    } else if (ty.isDynamicVector()) {
        return error.Unimplemented;
    } else {
        return error.UnsupportedType;
    };

    try ctx.emit(inst);
    return inst;
}

/// Debug operations (ISLE constructors)
pub fn aarch64_debugtrap(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_debugtrap");
    _ = ctx;
    // BRK #0 - debugger breakpoint
    return Inst{ .brk = .{ .imm = 0 } };
}

pub fn aarch64_nop(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_nop");
    _ = ctx;
    return Inst{ .nop = {} };
}

/// emit_val: Discard a Value result while preserving any emitted side effects.
/// Used by ISLE rules where `lower` returns an Inst but helper constructors return Value.
pub fn emit_val(_: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("emit_val");
    _ = ctx;
    return Inst{ .nop = {} };
}

/// emit_regs: Discard a ValueRegs result while preserving any emitted side effects.
/// Used by ISLE rules where `lower` returns an Inst but helper constructors return ValueRegs.
pub fn emit_regs(_: lower_mod.ValueRegs, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("emit_regs");
    _ = ctx;
    return Inst{ .nop = {} };
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
            .size = FpuOperandSize.size128,
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
            .imm = @intCast(first_byte),
            .size = .size32,
        } });

        return Inst{ .vec_dup = .{
            .dst = dst,
            .src = tmp_gpr.toReg(),
            .size = VecElemSize.size8x16,
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
    recordRule("aarch64_stack_addr");
    // Compute: SP + slot_offset + offset
    const slot_offset = ctx.getStackSlotOffset(stack_slot);
    const total_offset = @as(i64, slot_offset) + @as(i64, offset);

    const dst = lower_mod.WritableReg.allocReg(.int, ctx);

    if (total_offset >= 0 and total_offset <= 4095) {
        // Fits in immediate: ADD dst, SP, #offset
        return Inst{
            .add_imm = .{
                .dst = dst,
                .src = Reg.gpr(31), // SP
                .imm = @intCast(total_offset),
                .size = .size64,
            },
        };
    } else {
        // Large offset: MOV + ADD
        const offset_reg = lower_mod.WritableReg.allocReg(.int, ctx);
        try ctx.emit(Inst{ .mov_imm = .{
            .dst = offset_reg,
            .imm = @bitCast(@as(i64, total_offset)),
            .size = .size64,
        } });
        return Inst{
            .add_rr = .{
                .dst = dst,
                .src1 = Reg.gpr(31), // SP
                .src2 = offset_reg.toReg(),
                .size = .size64,
            },
        };
    }
}

fn stackSlotAddrReg(stack_slot: StackSlot, ctx: *lower_mod.LowerCtx(Inst)) !Reg {
    const addr_inst = try aarch64_stack_addr(stack_slot, 0, ctx);
    const dst = switch (addr_inst) {
        .add_imm => |data| data.dst,
        .add_rr => |data| data.dst,
        else => return error.UnexpectedStackAddrInst,
    };
    try ctx.emit(addr_inst);
    return dst.toReg();
}

/// Symbol address loading (ISLE constructors)
pub fn aarch64_symbol_value(extname: ExternalName, offset: i64, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_symbol_value");
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);

    const sym = try extfunc.symName(ctx.allocator, extname);

    // Materialize symbol address via ADRP + ADD :lo12:
    try ctx.emit(Inst{ .adrp_symbol = .{
        .dst = dst,
        .symbol = sym,
    } });
    const base = Inst{ .add_symbol_lo12 = .{
        .dst = dst,
        .src = dst.toReg(),
        .symbol = sym,
    } };
    try ctx.emit(base);

    if (offset == 0) return base;
    if (offset > 0 and offset <= 0xfff) {
        const inst = Inst{ .add_imm = .{
            .dst = dst,
            .src = dst.toReg(),
            .imm = @intCast(offset),
            .size = .size64,
        } };
        try ctx.emit(inst);
        return inst;
    }
    if (offset < 0 and offset >= -0xfff) {
        const inst = Inst{ .sub_imm = .{
            .dst = dst,
            .src = dst.toReg(),
            .imm = @intCast(-offset),
            .size = .size64,
        } };
        try ctx.emit(inst);
        return inst;
    }

    const off_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .mov_imm = .{
        .dst = off_reg,
        .imm = @bitCast(offset),
        .size = .size64,
    } });
    const inst = Inst{ .add_rr = .{
        .dst = dst,
        .src1 = dst.toReg(),
        .src2 = off_reg.toReg(),
        .size = .size64,
    } };
    try ctx.emit(inst);
    return inst;
}

pub fn aarch64_func_addr(extname: ExternalName, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_func_addr");
    // Function address is just symbol_value with offset 0
    return aarch64_symbol_value(extname, 0, ctx);
}

/// Overflow arithmetic (ISLE constructors)
/// Returns ValueRegs: [result, overflow_flag]
pub fn aarch64_uadd_overflow(ty: types.Type, a: lower_mod.Value, b: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    recordRule("aarch64_uadd_overflow");
    const a_reg = Reg.fromVReg(try ctx.getValueReg(a, .int));
    const b_reg = Reg.fromVReg(try ctx.getValueReg(b, .int));
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const size: OperandSize = if (ty.bits() == 64) .size64 else .size32;

    // ADDS: Add and set flags
    try ctx.emit(Inst{ .adds_rr = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = size,
    } });

    // CSET: Set register to 1 if carry, 0 otherwise
    const overflow_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .cs, // CS = carry set (unsigned >=)
            .size = size,
        },
    });

    return lower_mod.ValueRegs.pair(dst.toReg(), overflow_reg.toReg());
}

pub fn aarch64_usub_overflow(ty: types.Type, a: lower_mod.Value, b: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    recordRule("aarch64_usub_overflow");
    const a_reg = Reg.fromVReg(try ctx.getValueReg(a, .int));
    const b_reg = Reg.fromVReg(try ctx.getValueReg(b, .int));
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const size: OperandSize = if (ty.bits() == 64) .size64 else .size32;

    // SUBS: Subtract and set flags
    try ctx.emit(Inst{ .subs_rr = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = size,
    } });

    // CSET: Set register to 1 if borrow (carry clear), 0 otherwise
    const overflow_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .cc, // CC = carry clear (unsigned borrow)
            .size = size,
        },
    });

    return lower_mod.ValueRegs.pair(dst.toReg(), overflow_reg.toReg());
}

pub fn aarch64_sadd_overflow(ty: types.Type, a: lower_mod.Value, b: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    recordRule("aarch64_sadd_overflow");
    const a_reg = Reg.fromVReg(try ctx.getValueReg(a, .int));
    const b_reg = Reg.fromVReg(try ctx.getValueReg(b, .int));
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const size: OperandSize = if (ty.bits() == 64) .size64 else .size32;

    // ADDS: Add and set flags
    try ctx.emit(Inst{ .adds_rr = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = size,
    } });

    // CSET: Set register to 1 if signed overflow (V flag), 0 otherwise
    const overflow_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .vs, // VS = signed overflow
            .size = size,
        },
    });

    return lower_mod.ValueRegs.pair(dst.toReg(), overflow_reg.toReg());
}

pub fn aarch64_ssub_overflow(ty: types.Type, a: lower_mod.Value, b: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    recordRule("aarch64_ssub_overflow");
    const a_reg = Reg.fromVReg(try ctx.getValueReg(a, .int));
    const b_reg = Reg.fromVReg(try ctx.getValueReg(b, .int));
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    const size: OperandSize = if (ty.bits() == 64) .size64 else .size32;

    // SUBS: Subtract and set flags
    try ctx.emit(Inst{ .subs_rr = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = size,
    } });

    // CSET: Set register to 1 if signed overflow (V flag), 0 otherwise
    const overflow_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .vs, // VS = signed overflow
            .size = size,
        },
    });

    return lower_mod.ValueRegs.pair(dst.toReg(), overflow_reg.toReg());
}

fn tcAddr(base: Reg, offset: u32, ctx: *lower_mod.LowerCtx(Inst)) !Reg {
    if (offset == 0) return base;
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    if (offset <= 4095) {
        try ctx.emit(Inst{ .add_imm = .{
            .dst = dst,
            .src = base,
            .imm = @intCast(offset),
            .size = .size64,
        } });
    } else {
        const off = lower_mod.WritableReg.allocReg(.int, ctx);
        try ctx.emit(Inst{ .mov_imm = .{
            .dst = off,
            .imm = offset,
            .size = .size64,
        } });
        try ctx.emit(Inst{ .add_rr = .{
            .dst = dst,
            .src1 = base,
            .src2 = off.toReg(),
            .size = .size64,
        } });
    }
    return dst.toReg();
}

fn tcOutSp(ctx: *lower_mod.LowerCtx(Inst)) !Reg {
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .tailcall_sp = .{ .dst = dst } });
    return dst.toReg();
}

fn copyStructToStack(base: Reg, offset: u32, src: Reg, size: u32, ctx: *lower_mod.LowerCtx(Inst)) !void {
    const dst = try tcAddr(base, offset, ctx);
    var copy_insts = try abi_mod.generateStructCopy(ctx.getAllocator(), dst, src, size);
    defer copy_insts.deinit(ctx.getAllocator());

    for (copy_insts.items) |inst| {
        try ctx.emit(inst);
    }
}

fn tcStoreArg(base: Reg, offset: u32, src: Reg, ty: types.Type, ctx: *lower_mod.LowerCtx(Inst)) !void {
    const is_fp = ty.isFloat() or ty.isVector();
    if (is_fp) {
        const size = typeToFpuOperandSize(ty);
        const scale: u32 = switch (size) {
            .size32 => 2,
            .size64 => 3,
            .size128 => 4,
        };
        const max_off: u32 = @as(u32, 0xfff) << @as(u5, @intCast(scale));
        const align_mask: u32 = (@as(u32, 1) << @as(u5, @intCast(scale))) - 1;
        if (offset <= max_off and (offset & align_mask) == 0) {
            try ctx.emit(Inst{ .vstr = .{
                .src = src,
                .base = base,
                .offset = @intCast(offset),
                .size = size,
            } });
        } else {
            const addr = try tcAddr(base, offset, ctx);
            try ctx.emit(Inst{ .vstr = .{
                .src = src,
                .base = addr,
                .offset = 0,
                .size = size,
            } });
        }
    } else {
        if (offset <= 255) {
            try ctx.emit(Inst{ .str = .{
                .src = src,
                .base = base,
                .offset = @intCast(offset),
                .size = .size64,
            } });
        } else {
            const addr = try tcAddr(base, offset, ctx);
            try ctx.emit(Inst{ .str = .{
                .src = src,
                .base = addr,
                .offset = 0,
                .size = .size64,
            } });
        }
    }
}

/// Tail call operations (ISLE constructors)
pub fn aarch64_return_call(sig_ref: SigRef, name: ExternalName, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_return_call");
    // Tail call: marshal args, restore frame, branch (not call)
    //
    // AAPCS64 tail call requirements:
    // 1. Marshal arguments to ABI locations (X0-X7, V0-V7, stack)
    // 2. If callee needs MORE stack args than we have, adjust frame FIRST
    // 3. Restore callee-saved registers and frame pointer
    // 4. Branch (B/BR) not call (BL/BLR) - no link register update
    //
    // Key challenge: Stack argument overlap
    // - Caller's stack args are at [SP + caller_frame_size]
    // - Callee expects args at [SP + 0]
    // - We must copy args BEFORE deallocating frame to avoid corruption

    // Validate signature if available
    const sig = ctx.getSig(sig_ref) orelse {
        std.log.err("Tail call requires signature", .{});
        return error.MissingSignature;
    };

    if (args.len != sig.params.items.len) {
        std.log.err("Tail call argument count mismatch: got {}, expected {}", .{ args.len, sig.params.items.len });
        return error.ArgumentCountMismatch;
    }

    const call_conv = sig.call_conv;
    const abi_spec = abi_mod.abiSpecForCallConv(call_conv);

    const allocator = ctx.getAllocator();
    const arg_types = try collectArgTypes(args, ctx);
    defer allocator.free(arg_types);

    for (sig.params.items, 0..) |param, idx| {
        const arg_type = arg_types[idx];
        if (!arg_type.eql(param.value_type)) {
            std.log.err("Tail call argument {} type mismatch: got {f}, expected {f}", .{ idx, arg_type, param.value_type });
            return error.SignatureArgumentTypeMismatch;
        }
    }

    var layout = try abi_mod.computeCallLayout(allocator, arg_types, sig, call_conv, &ctx.func.struct_store);
    defer layout.deinit(allocator);

    var stack_ops = try collectCallOps(&layout, args, arg_types, abi_spec, ctx);
    defer stack_ops.deinit(allocator);

    if (stack_ops.items.len > 0) {
        const out_sp = try tcOutSp(ctx);
        try emitCallStackOps(stack_ops.items, out_sp, ctx);
    }

    // Load target address via GOT before frame restoration
    const symbol_name = switch (name) {
        .testcase => |n| n,
        .user => |u| blk: {
            var buf: [64]u8 = undefined;
            const formatted = std.fmt.bufPrint(&buf, "u{d}:{d}", .{ u.namespace, u.index }) catch "external_user_func";
            const owned = try ctx.getAllocator().dupe(u8, formatted);
            break :blk owned;
        },
    };
    const target_reg = Reg.gpr(9); // X9: caller-saved, safe across tail call setup
    const tmp = lower_mod.WritableReg.fromReg(target_reg);
    try ctx.emit(Inst{ .load_ext_name_got = .{ .dst = tmp, .symbol = symbol_name } });

    // Restore callee-saved registers and frame at emission time.
    try ctx.emit(Inst{ .epilogue_placeholder = {} });

    // Branch to target via register (BR, not BL - no link register update)
    return Inst{ .br = .{ .target = target_reg } };
}

pub fn aarch64_return_call_indirect(sig_ref: SigRef, ptr: lower_mod.Value, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_return_call_indirect");
    // Indirect tail call: marshal args, restore frame, branch via register
    // Same requirements as direct tail call, but branch through register instead of symbol

    // Validate signature
    const sig = ctx.getSig(sig_ref) orelse {
        std.log.err("Tail call requires signature", .{});
        return error.MissingSignature;
    };

    if (args.len != sig.params.items.len) {
        std.log.err("Tail call argument count mismatch: got {}, expected {}", .{ args.len, sig.params.items.len });
        return error.ArgumentCountMismatch;
    }

    // Get function pointer into a safe register (X9 - caller-saved, not used for args)
    const ptr_reg = try ctx.getValueReg(ptr, .int);
    const target_reg = Reg.gpr(9);
    if (!ptr_reg.toReg().eq(target_reg)) {
        try ctx.emit(Inst{ .mov_rr = .{
            .dst = lower_mod.WritableReg.fromReg(target_reg),
            .src = ptr_reg.toReg(),
            .size = .size64,
        } });
    }

    const call_conv = sig.call_conv;
    const abi_spec = abi_mod.abiSpecForCallConv(call_conv);

    const allocator = ctx.getAllocator();
    const arg_types = try collectArgTypes(args, ctx);
    defer allocator.free(arg_types);

    for (sig.params.items, 0..) |param, idx| {
        const arg_type = arg_types[idx];
        if (!arg_type.eql(param.value_type)) {
            std.log.err("Tail call argument {} type mismatch: got {f}, expected {f}", .{ idx, arg_type, param.value_type });
            return error.SignatureArgumentTypeMismatch;
        }
    }

    var layout = try abi_mod.computeCallLayout(allocator, arg_types, sig, call_conv, &ctx.func.struct_store);
    defer layout.deinit(allocator);

    var stack_ops = try collectCallOps(&layout, args, arg_types, abi_spec, ctx);
    defer stack_ops.deinit(allocator);

    if (stack_ops.items.len > 0) {
        const out_sp = try tcOutSp(ctx);
        try emitCallStackOps(stack_ops.items, out_sp, ctx);
    }

    // Restore callee-saved registers and frame at emission time.
    try ctx.emit(Inst{ .epilogue_placeholder = {} });

    // Branch via register (BR, not BLR - no link register update)
    return Inst{ .br = .{ .target = target_reg } };
}

/// Vector test operations (ISLE constructors)
pub fn aarch64_vall_true(x: lower_mod.Value, ty: types.Type, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_vall_true");
    const x_reg = (try ctx.getValueReg(x, .vector)).toReg();
    const vec_size = try vectorSizeFromType(ty);

    // Use UMINV to get minimum of all lanes
    const min_reg = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_uminv = .{
        .dst = min_reg,
        .src = x_reg,
        .size = vec_size,
    } });

    // Extract scalar and compare with 0
    const scalar_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .vec_extract_lane = .{
        .dst = scalar_reg,
        .src = min_reg.toReg(),
        .lane = 0,
        .size = vec_size,
    } });

    // Compare: all true if min != 0
    try ctx.emit(Inst{ .cmp_imm = .{
        .src = scalar_reg.toReg(),
        .imm = u8_into_imm12(0),
        .size = .size64,
    } });

    // CSET: Set result to 1 if NE, 0 otherwise
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{ .cset = .{ .dst = dst, .cond = .ne, .size = .size64 } };
}

pub fn aarch64_vany_true(x: lower_mod.Value, ty: types.Type, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_vany_true");
    const x_reg = (try ctx.getValueReg(x, .vector)).toReg();
    const vec_size = try vectorSizeFromType(ty);

    // Use UMAXV to get maximum of all lanes
    const max_reg = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_umaxv = .{
        .dst = max_reg,
        .src = x_reg,
        .size = vec_size,
    } });

    // Extract scalar and compare with 0
    const scalar_reg = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .vec_extract_lane = .{
        .dst = scalar_reg,
        .src = max_reg.toReg(),
        .lane = 0,
        .size = vec_size,
    } });

    // Compare: any true if max != 0
    try ctx.emit(Inst{ .cmp_imm = .{
        .src = scalar_reg.toReg(),
        .imm = u8_into_imm12(0),
        .size = .size64,
    } });

    // CSET: Set result to 1 if NE, 0 otherwise
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{ .cset = .{ .dst = dst, .cond = .ne, .size = .size64 } };
}

pub fn aarch64_vhigh_bits(vec: lower_mod.Value, ty: types.Type, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_vhigh_bits");
    const vec_reg = (try ctx.getValueReg(vec, .vector)).toReg();
    const lane_bits = ty.laneBits();

    // Extract high bit from each lane by shifting and accumulating
    // For I8X16: shift each byte left by 7, then ADDV to sum
    const shift_amount: u8 = @intCast(lane_bits - 1);

    // SHL to move high bit to position
    const shifted = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_shift_imm = .{
        .dst = shifted,
        .rn = vec_reg,
        .imm = shift_amount,
        .op = .Shl,
        .size = try vectorSizeFromType(ty),
    } });

    // ADDV to sum all lanes (creates bitmask)
    const sum_reg = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    try ctx.emit(Inst{ .vec_addv = .{
        .dst = sum_reg,
        .src = shifted.toReg(),
        .size = try vectorSizeFromType(ty),
    } });

    // Extract to GPR
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{ .vec_extract_lane = .{
        .dst = dst,
        .src = sum_reg.toReg(),
        .lane = 0,
        .size = try vectorSizeFromType(ty),
    } };
}

fn vectorSizeFromType(ty: types.Type) !VecElemSize {
    if (!ty.isVector()) return error.ExpectedVectorType;
    const elem_bits = ty.laneBits();
    const lanes = ty.laneCount();

    return switch (elem_bits) {
        8 => switch (lanes) {
            8 => .size8x8,
            16 => .size8x16,
            else => error.UnsupportedVectorType,
        },
        16 => switch (lanes) {
            4 => .size16x4,
            8 => .size16x8,
            else => error.UnsupportedVectorType,
        },
        32 => switch (lanes) {
            2 => .size32x2,
            4 => .size32x4,
            else => error.UnsupportedVectorType,
        },
        64 => switch (lanes) {
            2 => .size64x2,
            else => error.UnsupportedVectorType,
        },
        else => error.UnsupportedVectorType,
    };
}

const StackOp = union(enum) {
    scalar: struct {
        reg: Reg,
        ty: Type,
        offset: u32,
    },
    struct_copy: struct {
        src: Reg,
        size: u32,
        offset: u32,
    },
};

fn collectArgTypes(args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) ![]Type {
    const allocator = ctx.getAllocator();
    const arg_types = try allocator.alloc(Type, args.len);
    errdefer allocator.free(arg_types);
    for (args, 0..) |arg_value, idx| {
        arg_types[idx] = ctx.func.dfg.valueType(arg_value) orelse return error.MissingValueType;
    }
    return arg_types;
}

fn collectCallOps(
    layout: *const abi_mod.CallLayout,
    args: lower_mod.ValueSlice,
    arg_types: []const Type,
    abi_spec: mach_abi.ABIMachineSpec(u64),
    ctx: *lower_mod.LowerCtx(Inst),
) !std.ArrayList(StackOp) {
    if (args.len != layout.arg_locs.len or args.len != arg_types.len) {
        return error.ArgumentCountMismatch;
    }

    var stack_ops = std.ArrayList(StackOp){};
    errdefer stack_ops.deinit(ctx.getAllocator());

    for (args, 0..) |arg_value, idx| {
        const arg_type = arg_types[idx];
        switch (layout.arg_locs[idx]) {
            .sret => {
                const sret_reg = Reg.fromVReg(try ctx.getValueReg(arg_value, .int));
                const x8 = Reg.gpr(8);
                if (!sret_reg.eq(x8)) {
                    try ctx.emit(Inst{ .mov_rr = .{
                        .dst = lower_mod.WritableReg.fromReg(x8),
                        .src = sret_reg,
                        .size = .size64,
                    } });
                }
            },
            .int_reg => |reg_idx| {
                const arg_reg = Reg.fromVReg(try ctx.getValueReg(arg_value, .int));
                const abi_preg = abi_spec.int_arg_regs[reg_idx];
                const abi_reg = Reg.gpr(abi_preg.hwEnc());
                if (!arg_reg.eq(abi_reg)) {
                    try ctx.emit(Inst{ .mov_rr = .{
                        .dst = lower_mod.WritableReg.fromReg(abi_reg),
                        .src = arg_reg,
                        .size = .size64,
                    } });
                }
            },
            .fp_reg => |reg_idx| {
                const arg_reg = Reg.fromVReg(try ctx.getValueReg(arg_value, .float));
                const abi_preg = abi_spec.float_arg_regs[reg_idx];
                const abi_reg = Reg.fpr(abi_preg.hwEnc());
                if (!arg_reg.eq(abi_reg)) {
                    try ctx.emit(Inst{ .fmov = .{
                        .dst = lower_mod.WritableReg.fromReg(abi_reg),
                        .src = arg_reg,
                        .size = typeToFpuOperandSize(arg_type),
                    } });
                }
            },
            .stack => |stack_loc| {
                const is_fp = arg_type.isFloat() or arg_type.isVector();
                const arg_reg = Reg.fromVReg(try ctx.getValueReg(arg_value, if (is_fp) .float else .int));
                try stack_ops.append(ctx.getAllocator(), .{ .scalar = .{ .reg = arg_reg, .ty = arg_type, .offset = stack_loc.offset } });
            },
            .struct_int => |loc| {
                const struct_ptr = Reg.fromVReg(try ctx.getValueReg(arg_value, .int));

                const val1_reg = lower_mod.WritableReg.allocReg(.int, ctx);
                try ctx.emit(Inst{ .ldr = .{
                    .dst = val1_reg,
                    .base = struct_ptr,
                    .offset = 0,
                    .size = .size64,
                } });

                const abi_preg1 = abi_spec.int_arg_regs[loc.start];
                const abi_reg1 = Reg.gpr(abi_preg1.hwEnc());
                if (!val1_reg.toReg().eq(abi_reg1)) {
                    try ctx.emit(Inst{ .mov_rr = .{
                        .dst = lower_mod.WritableReg.fromReg(abi_reg1),
                        .src = val1_reg.toReg(),
                        .size = .size64,
                    } });
                }

                if (loc.count == 2) {
                    const val2_reg = lower_mod.WritableReg.allocReg(.int, ctx);
                    try ctx.emit(Inst{ .ldr = .{
                        .dst = val2_reg,
                        .base = struct_ptr,
                        .offset = 8,
                        .size = .size64,
                    } });

                    const abi_preg2 = abi_spec.int_arg_regs[loc.start + 1];
                    const abi_reg2 = Reg.gpr(abi_preg2.hwEnc());
                    if (!val2_reg.toReg().eq(abi_reg2)) {
                        try ctx.emit(Inst{ .mov_rr = .{
                            .dst = lower_mod.WritableReg.fromReg(abi_reg2),
                            .src = val2_reg.toReg(),
                            .size = .size64,
                        } });
                    }
                }
            },
            .struct_fp => |loc| {
                const struct_fields = try structFields(ctx, arg_type);
                if (struct_fields.len < loc.count) return error.MissingStructFields;

                const struct_ptr = Reg.fromVReg(try ctx.getValueReg(arg_value, .int));
                const elem_ty = loc.elem_ty;
                const is_vec = elem_ty.isVector();

                var field_idx: u8 = 0;
                while (field_idx < loc.count) : (field_idx += 1) {
                    const offset: i16 = @intCast(struct_fields[field_idx].offset);
                    const field_reg = lower_mod.WritableReg.allocReg(.float, ctx);
                    try ctx.emit(Inst{ .vldr = .{
                        .dst = field_reg,
                        .base = struct_ptr,
                        .offset = offset,
                        .size = typeToFpuOperandSize(elem_ty),
                    } });

                    const abi_preg = abi_spec.float_arg_regs[loc.start + field_idx];
                    const abi_reg = Reg.fpr(abi_preg.hwEnc());
                    if (!field_reg.toReg().eq(abi_reg)) {
                        if (is_vec) {
                            try ctx.emit(Inst{ .vec_orr = .{
                                .dst = lower_mod.WritableReg.fromReg(abi_reg),
                                .src1 = field_reg.toReg(),
                                .src2 = field_reg.toReg(),
                                .size = typeToFpuOperandSize(elem_ty),
                            } });
                        } else {
                            try ctx.emit(Inst{ .fmov = .{
                                .dst = lower_mod.WritableReg.fromReg(abi_reg),
                                .src = field_reg.toReg(),
                                .size = typeToFpuOperandSize(elem_ty),
                            } });
                        }
                    }
                }
            },
            .struct_stack => |stack_loc| {
                const struct_ptr = Reg.fromVReg(try ctx.getValueReg(arg_value, .int));
                const struct_size = try tySize(ctx, arg_type);
                try stack_ops.append(ctx.getAllocator(), .{ .struct_copy = .{ .src = struct_ptr, .size = struct_size, .offset = stack_loc.offset } });
            },
            .struct_indirect_reg => |reg_idx| {
                const struct_size = try tySize(ctx, arg_type);
                const stack_slot = try ctx.allocStackSlot(struct_size, try tyAlign(ctx, arg_type));
                const stack_slot_addr = try stackSlotAddrReg(stack_slot, ctx);

                var copy_insts = try abi_mod.generateStructCopy(
                    ctx.getAllocator(),
                    stack_slot_addr,
                    Reg.fromVReg(try ctx.getValueReg(arg_value, .int)),
                    struct_size,
                );
                defer copy_insts.deinit(ctx.getAllocator());
                for (copy_insts.items) |inst| {
                    try ctx.emit(inst);
                }

                const abi_preg = abi_spec.int_arg_regs[reg_idx];
                const abi_reg = Reg.gpr(abi_preg.hwEnc());
                if (!stack_slot_addr.eq(abi_reg)) {
                    try ctx.emit(Inst{ .mov_rr = .{
                        .dst = lower_mod.WritableReg.fromReg(abi_reg),
                        .src = stack_slot_addr,
                        .size = .size64,
                    } });
                }
            },
            .struct_indirect_stack => |stack_loc| {
                const struct_size = try tySize(ctx, arg_type);
                const stack_slot = try ctx.allocStackSlot(struct_size, try tyAlign(ctx, arg_type));
                const stack_slot_addr = try stackSlotAddrReg(stack_slot, ctx);

                var copy_insts = try abi_mod.generateStructCopy(
                    ctx.getAllocator(),
                    stack_slot_addr,
                    Reg.fromVReg(try ctx.getValueReg(arg_value, .int)),
                    struct_size,
                );
                defer copy_insts.deinit(ctx.getAllocator());
                for (copy_insts.items) |inst| {
                    try ctx.emit(inst);
                }

                try stack_ops.append(ctx.getAllocator(), .{ .scalar = .{
                    .reg = stack_slot_addr,
                    .ty = arg_type,
                    .offset = stack_loc.offset,
                } });
            },
        }
    }

    return stack_ops;
}

fn emitCallStackOps(
    ops: []const StackOp,
    base: Reg,
    ctx: *lower_mod.LowerCtx(Inst),
) !void {
    for (ops) |op| {
        switch (op) {
            .scalar => |data| try tcStoreArg(base, data.offset, data.reg, data.ty, ctx),
            .struct_copy => |data| try copyStructToStack(base, data.offset, data.src, data.size, ctx),
        }
    }
}

test "call layout stack ops for struct spill" {
    const testing = std.testing;

    const sig = signature_mod.Signature.init(testing.allocator, .system_v);
    var func = try lower_mod.Function.init(testing.allocator, "test_struct_spill", sig);
    defer func.deinit();

    const fields = [_]types.StructField{
        .{ .ty = Type.I64, .offset = 0 },
        .{ .ty = Type.I64, .offset = 8 },
    };
    const id = try func.struct_store.intern(&fields, 16);
    const struct_ty = Type.fromStructId(id);

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);
    const param_tys = [_]Type{
        Type.I64,  Type.I64, Type.I64, Type.I64,
        Type.I64,  Type.I64, Type.I64, Type.I64,
        struct_ty,
    };
    try func.dfg.setBlockParams(block0, &param_tys);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    try ctx.allocateSSAVRegs();
    _ = try ctx.startBlock(block0);
    const allocator = ctx.getAllocator();

    const args = func.dfg.blockParams(block0);
    const arg_types = try collectArgTypes(args, &ctx);
    defer ctx.getAllocator().free(arg_types);

    var layout = try abi_mod.computeCallLayout(testing.allocator, arg_types, null, .system_v, &func.struct_store);
    defer layout.deinit(testing.allocator);

    const abi_spec = abi_mod.abiSpecForCallConv(.system_v);
    var stack_ops = try collectCallOps(&layout, args, arg_types, abi_spec, &ctx);
    defer stack_ops.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), stack_ops.items.len);
    switch (stack_ops.items[0]) {
        .struct_copy => |op| {
            try testing.expectEqual(@as(u32, 0), op.offset);
            try testing.expectEqual(@as(u32, 16), op.size);
        },
        else => try testing.expect(false),
    }
}

test "tailcall uses call layout for struct stack args" {
    const testing = std.testing;

    const sig = signature_mod.Signature.init(testing.allocator, .system_v);
    var func = try lower_mod.Function.init(testing.allocator, "test_tailcall_struct_stack", sig);
    defer func.deinit();

    const fields = [_]types.StructField{
        .{ .ty = Type.I64, .offset = 0 },
        .{ .ty = Type.I64, .offset = 8 },
    };
    const id = try func.struct_store.intern(&fields, 16);
    const struct_ty = Type.fromStructId(id);

    var callee_sig = signature_mod.Signature.init(testing.allocator, .system_v);
    try callee_sig.params.append(testing.allocator, signature_mod.AbiParam.new(Type.I64));
    try callee_sig.params.append(testing.allocator, signature_mod.AbiParam.new(Type.I64));
    try callee_sig.params.append(testing.allocator, signature_mod.AbiParam.new(Type.I64));
    try callee_sig.params.append(testing.allocator, signature_mod.AbiParam.new(Type.I64));
    try callee_sig.params.append(testing.allocator, signature_mod.AbiParam.new(Type.I64));
    try callee_sig.params.append(testing.allocator, signature_mod.AbiParam.new(Type.I64));
    try callee_sig.params.append(testing.allocator, signature_mod.AbiParam.new(Type.I64));
    try callee_sig.params.append(testing.allocator, signature_mod.AbiParam.new(Type.I64));
    try callee_sig.params.append(testing.allocator, signature_mod.AbiParam.new(struct_ty));

    const sig_ref = try func.signatures.push(callee_sig);

    const block0 = try func.dfg.makeBlock();
    try func.layout.appendBlock(block0);
    const param_tys = [_]Type{
        Type.I64,  Type.I64, Type.I64, Type.I64,
        Type.I64,  Type.I64, Type.I64, Type.I64,
        struct_ty,
    };
    try func.dfg.setBlockParams(block0, &param_tys);

    var vcode = hoist.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var ctx = lower_mod.LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer ctx.deinit();
    try ctx.allocateSSAVRegs();
    _ = try ctx.startBlock(block0);

    const args = func.dfg.blockParams(block0);
    const term = try aarch64_return_call(sig_ref, .{ .testcase = "callee" }, args, &ctx);
    try ctx.emit(term);

    var found_stp = false;
    for (vcode.insns.items) |inst| {
        switch (inst) {
            .stp => found_stp = true,
            else => {},
        }
        if (found_stp) break;
    }

    try testing.expect(found_stp);
}

/// Call operations (ISLE constructors)
pub fn aarch64_call(sig_ref: SigRef, name: ExternalName, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    recordRule("aarch64_call");
    // Get signature and calling convention
    const sig = ctx.getSig(sig_ref);
    const call_conv = if (sig) |s| s.call_conv else signature_mod.CallConv.system_v;
    const is_varargs = if (sig) |s| s.is_varargs else false;

    const allocator = ctx.getAllocator();
    const arg_types = try collectArgTypes(args, ctx);
    defer allocator.free(arg_types);

    // Validate signature if available
    if (sig) |s| {
        // For variadic calls, args.len >= fixed params
        const expected = s.params.items.len;
        if (is_varargs) {
            if (args.len < expected) {
                std.log.err("Call argument count mismatch: got {}, expected >= {}", .{ args.len, expected });
                return error.SignatureArgumentCountMismatch;
            }
        } else {
            if (args.len != expected) {
                std.log.err("Call argument count mismatch: got {}, expected {}", .{ args.len, expected });
                return error.SignatureArgumentCountMismatch;
            }
        }

        // Check fixed argument types match
        for (0..expected) |i| {
            const arg_type = arg_types[i];
            const param_type = s.params.items[i].value_type;
            if (!arg_type.eql(param_type)) {
                std.log.err("Call argument {} type mismatch: got {f}, expected {f}", .{ i, arg_type, param_type });
                return error.SignatureArgumentTypeMismatch;
            }
        }
    }

    const abi_spec = abi_mod.abiSpecForCallConv(call_conv);
    var layout = try abi_mod.computeCallLayout(allocator, arg_types, sig, call_conv, &ctx.func.struct_store);
    defer layout.deinit(allocator);

    if (layout.stack_size > ctx.getOutStackMax()) {
        return error.OutgoingStackTooSmall;
    }

    var stack_ops = try collectCallOps(&layout, args, arg_types, abi_spec, ctx);
    defer stack_ops.deinit(allocator);
    try emitCallStackOps(stack_ops.items, Reg.gpr(31), ctx);

    // Call via GOT for PIC: ADRP+LDR+BLR
    // Format ExternalName to symbol name per Cranelift conventions
    const symbol_name = switch (name) {
        .testcase => |n| n,
        .user => |u| blk: {
            // Format user names as u{namespace}:{index}
            var buf: [64]u8 = undefined;
            const formatted = std.fmt.bufPrint(&buf, "u{d}:{d}", .{ u.namespace, u.index }) catch "external_user_func";
            const owned = try ctx.getAllocator().dupe(u8, formatted);
            break :blk owned;
        },
    };

    // Load function address via GOT and call indirectly
    const tmp = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .load_ext_name_got = .{ .dst = tmp, .symbol = symbol_name } });
    try ctx.emit(Inst{ .blr = .{ .target = tmp.toReg() } });

    // Marshal return values according to AAPCS64
    return marshalReturnValues(sig_ref, ctx);
}

/// Marshal return values from ABI registers according to AAPCS64.
/// Handles:
/// - Single/multiple integer returns in X0-X7
/// - Single/multiple FP/SIMD returns in V0-V7
/// - i128 in X0+X1
/// - HFA in V0-V3
/// - Indirect returns via X8 pointer
fn marshalReturnValues(sig_ref: SigRef, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    const sig = ctx.getSig(sig_ref) orelse {
        // No signature available - assume single integer return in X0
        return lower_mod.ValueRegs.single(Reg.gpr(0));
    };

    const returns = sig.returns.items;

    if (returns.len == 0) {
        // No return values
        return lower_mod.ValueRegs.single(Reg.invalid());
    }

    if (returns.len == 1) {
        // Single return value - use classifyReturn
        const ret_type = returns[0].value_type;
        const ret_loc = abi_mod.classifyReturn(ret_type, &ctx.func.struct_store);

        return switch (ret_loc) {
            .single_reg => |preg| lower_mod.ValueRegs.single(Reg.fromPReg(preg)),
            .reg_pair => |pair| lower_mod.ValueRegs.pair(
                Reg.fromPReg(pair.lo),
                Reg.fromPReg(pair.hi),
            ),
            .hfa => |hfa| {
                // HFA returns in V0-V3 - assemble into struct
                // Allocate memory for return struct
                const classification = try abi_mod.classifyStructIr(ret_type, &ctx.func.struct_store);
                if (classification.class != .hfa and classification.class != .hva) {
                    return error.ExpectedStructType;
                }
                const struct_size = try tySize(ctx, ret_type);
                const stack_slot = try ctx.allocStackSlot(struct_size, try tyAlign(ctx, ret_type));
                const stack_slot_addr = try stackSlotAddrReg(stack_slot, ctx);

                // Store each FP register field to struct memory
                const struct_fields = try structFields(ctx, ret_type);
                const elem_ty = classification.elem_ty.?;

                for (0..hfa.count) |field_idx| {
                    if (field_idx >= struct_fields.len) break;
                    const preg = hfa.regs[field_idx];

                    const offset: i16 = @intCast(struct_fields[field_idx].offset);
                    const src_reg = Reg.fromPReg(preg);

                    try ctx.emit(Inst{ .vstr = .{
                        .src = src_reg,
                        .base = stack_slot_addr,
                        .offset = offset,
                        .size = typeToFpuOperandSize(elem_ty),
                    } });
                }

                // Return pointer to assembled struct
                return lower_mod.ValueRegs.single(stack_slot_addr);
            },
            .indirect => {
                // Indirect return via X8 pointer
                // The callee wrote the result to the address in X8
                // Return X8 as the pointer - IR consumers will load from it
                return lower_mod.ValueRegs.single(Reg.gpr(8));
            },
        };
    }

    // Multiple return values
    // AAPCS64 allows up to 8 integer (X0-X7) + 8 FP (V0-V7) returns
    var int_count: u8 = 0;
    var fp_count: u8 = 0;
    var regs: [16]Reg = undefined;
    var reg_count: usize = 0;

    for (returns) |ret_param| {
        const ret_type = ret_param.value_type;
        const is_fp = ret_type.isFloat() or ret_type.isVector();

        if (!is_fp) {
            if (!ret_type.isInt() and !ret_type.isRef()) {
                return error.UnsupportedReturnType;
            }
            if (ret_type.isInt() and ret_type.bits() > 64) {
                return error.UnsupportedReturnType;
            }
        }

        if (is_fp) {
            if (fp_count >= 8) {
                std.log.err("Too many FP return values: max 8 allowed", .{});
                return error.TooManyReturnValues;
            }
            regs[reg_count] = Reg.fpr(@intCast(fp_count));
            fp_count += 1;
        } else {
            if (int_count >= 8) {
                std.log.err("Too many integer return values: max 8 allowed", .{});
                return error.TooManyReturnValues;
            }
            regs[reg_count] = Reg.gpr(@intCast(int_count));
            int_count += 1;
        }
        reg_count += 1;
    }

    // Return the collected registers
    return switch (reg_count) {
        1 => lower_mod.ValueRegs.single(regs[0]),
        2 => lower_mod.ValueRegs.pair(regs[0], regs[1]),
        3 => lower_mod.ValueRegs.triple(regs[0], regs[1], regs[2]),
        4 => lower_mod.ValueRegs.quad(regs[0], regs[1], regs[2], regs[3]),
        else => {
            std.log.err("Return value count {} exceeds max 4", .{reg_count});
            return error.TooManyReturnValues;
        },
    };
}

pub fn aarch64_call_indirect(sig_ref: SigRef, ptr: lower_mod.Value, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    recordRule("aarch64_call_indirect");
    // Get signature and calling convention
    const sig = ctx.getSig(sig_ref);
    const call_conv = if (sig) |s| s.call_conv else signature_mod.CallConv.system_v;
    const is_varargs = if (sig) |s| s.is_varargs else false;

    const allocator = ctx.getAllocator();
    const arg_types = try collectArgTypes(args, ctx);
    defer allocator.free(arg_types);

    // Validate signature if available
    if (sig) |s| {
        // For variadic calls, args.len >= fixed params
        const expected = s.params.items.len;
        if (is_varargs) {
            if (args.len < expected) {
                std.log.err("Call_indirect argument count mismatch: got {}, expected >= {}", .{ args.len, expected });
                return error.SignatureArgumentCountMismatch;
            }
        } else {
            if (args.len != expected) {
                std.log.err("Call_indirect argument count mismatch: got {}, expected {}", .{ args.len, expected });
                return error.SignatureArgumentCountMismatch;
            }
        }

        // Check fixed argument types match
        for (0..expected) |i| {
            const arg_type = arg_types[i];
            const param_type = s.params.items[i].value_type;
            if (!arg_type.eql(param_type)) {
                std.log.err("Call_indirect argument {} type mismatch: got {f}, expected {f}", .{ i, arg_type, param_type });
                return error.SignatureArgumentTypeMismatch;
            }
        }
    }

    const abi_spec = abi_mod.abiSpecForCallConv(call_conv);

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

    var layout = try abi_mod.computeCallLayout(allocator, arg_types, sig, call_conv, &ctx.func.struct_store);
    defer layout.deinit(allocator);

    if (layout.stack_size > ctx.getOutStackMax()) {
        return error.OutgoingStackTooSmall;
    }

    var stack_ops = try collectCallOps(&layout, args, arg_types, abi_spec, ctx);
    defer stack_ops.deinit(allocator);
    try emitCallStackOps(stack_ops.items, Reg.gpr(31), ctx);

    // Indirect call: BLR (branch with link to register)
    try ctx.emit(Inst{ .blr = .{ .target = temp_ptr } });

    // Marshal return values according to AAPCS64
    return marshalReturnValues(sig_ref, ctx);
}

pub fn aarch64_try_call(sig_ref: SigRef, name: ExternalName, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    recordRule("aarch64_try_call");
    // try_call emits the same call sequence as aarch64_call.
    // Exception routing uses LSDA + unwinder metadata attached by codegen:
    // on normal return, lowering branches to normal_successor; on exception,
    // unwinding transfers control to exception_successor landing pad.

    // Delegate to regular call implementation for the functional part
    return aarch64_call(sig_ref, name, args, ctx);
}

pub fn aarch64_try_call_indirect(sig_ref: SigRef, ptr: lower_mod.Value, args: lower_mod.ValueSlice, ctx: *lower_mod.LowerCtx(Inst)) !lower_mod.ValueRegs {
    recordRule("aarch64_try_call_indirect");
    // Indirect call with exception handling support
    // Uses same ABI marshaling as regular indirect call; control-flow edges
    // are emitted in aarch64_lower_generated.zig (normal successor), while
    // the exception successor is handled via LSDA/unwinder.

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
        const sh: u7 = @intCast(i * 8);
        const byte: u8 = @truncate(imm >> sh);
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
        const sh: u7 = @intCast(i * 16);
        const hword: u16 = @truncate(imm >> sh);
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
        const sh: u7 = @intCast(i * 32);
        const word: u32 = @truncate(imm >> sh);
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
        const sh: u7 = @intCast(i * 8);
        const actual: u8 = @truncate(imm >> sh);
        if (actual != expected) return null;
    }

    // Return starting byte offset (must be < 16 for valid EXT)
    if (first_byte < 16) return first_byte;
    return null;
}

/// u128_from_immediate - Extract u128 constant from Immediate
/// Used for matching specific shuffle patterns (UZP/ZIP/TRN/REV)
pub fn u128_from_immediate(actual: u128) ?u128 {
    return actual;
}

test "u128_from_immediate returns value" {
    const testing = std.testing;
    const value: u128 = 0x1e1c_1a18_1614_1210_0e0c_0a08_0604_0200;
    try testing.expectEqual(value, u128_from_immediate(value).?);
}

/// shuffle_tbl_fallback_mask - Return mask only for non-specialized shuffle masks.
/// This avoids overmatching in the constant-pattern chain and routes unmatched
/// masks to TBL fallback first.
pub fn shuffle_tbl_fallback_mask(actual: u128) ?u128 {
    return switch (actual) {
        // UZP patterns.
        0x1e1c_1a18_1614_1210_0e0c_0a08_0604_0200,
        0x1f1d_1b19_1715_1311_0f0d_0b09_0705_0301,
        0x1d1c_1918_1514_1110_0d0c_0908_0504_0100,
        0x1f1e_1b1a_1716_1312_0f0e_0b0a_0706_0302,
        0x1b1a1918_13121110_0b0a0908_03020100,
        0x1f1e1d1c_17161514_0f0e0d0c_07060504,
        0x1716151413121110_0706050403020100,
        0x1f1e1d1c1b1a1918_0f0e0d0c0b0a0908,
        // ZIP patterns.
        0x1707_1606_1505_1404_1303_1202_1101_1000,
        0x1f0f_1e0e_1d0d_1c0c_1b0b_1a0a_1909_1808,
        0x1716_0706_1514_0504_1312_0302_1110_0100,
        0x1f1e_0f0e_1d1c_0d0c_1b1a_0b0a_1918_0908,
        0x17161514_07060504_13121110_03020100,
        0x1f1e1d1c_0f0e0d0c_1b1a1918_0b0a0908,
        // TRN patterns.
        0x1e0e_1c0c_1a0a_1808_1606_1404_1202_1000,
        0x1f0f_1d0d_1b0b_1909_1707_1505_1303_1101,
        0x1d1c_0d0c_1918_0908_1514_0504_1110_0100,
        0x1f1e_0f0e_1b1a_0b0a_1716_0706_1312_0302,
        0x1b1a1918_0b0a0908_13121110_03020100,
        0x1f1e1d1c_0f0e0d0c_17161514_07060504,
        // REV patterns.
        0x0e0f_0c0d_0a0b_0809_0607_0405_0203_0001,
        0x0c0d0e0f_08090a0b_04050607_00010203,
        0x0d0c0f0e_09080b0a_05040706_01000302,
        0x08090a0b0c0d0e0f_0001020304050607,
        0x09080b0a0d0c0f0e_0100030205040706,
        0x0b0a09080f0e0d0c_0302010007060504,
        => null,
        else => actual,
    };
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
    recordRule("aarch64_shuffle_tbl");
    const a_reg = try getValueRegVec(ctx, a);
    const b_reg = try getValueRegVec(ctx, b);

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
        .size = .size64,
    } });

    try ctx.emit(Inst{ .mov_imm = .{
        .dst = tmp_hi,
        .imm = @bitCast(mask_hi),
        .size = .size64,
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
        .size = .size64x2,
    } });

    // TBL with two table registers requires consecutive registers. Use the
    // reserved scratch vector regs v16-v17 as the table base.
    const tbl0 = Reg.fromPReg(PReg.new(.vector, 16));
    const tbl1 = Reg.fromPReg(PReg.new(.vector, 17));
    try ctx.emit(Inst{ .vec_orr = .{
        .dst = lower_mod.WritableReg.fromReg(tbl0),
        .src1 = a_reg,
        .src2 = a_reg,
        .size = .size128,
    } });
    try ctx.emit(Inst{ .vec_orr = .{
        .dst = lower_mod.WritableReg.fromReg(tbl1),
        .src1 = b_reg,
        .src2 = b_reg,
        .size = .size128,
    } });

    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);
    return Inst{
        .tbl = .{
            .dst = dst,
            .table = tbl0,
            .indices = mask_reg.toReg(),
            .table_regs = 1, // 2 consecutive regs: v16-v17
        },
    };
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
    const addend_reg = try getValueRegVec(ctx, addend);
    const mul1_reg = try getValueRegVec(ctx, multiplicand1);
    const mul2_reg = try getValueRegVec(ctx, multiplicand2);

    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    try ctx.emit(Inst{ .vec_rrr_mod = .{
        .op = op,
        .dst = dst,
        .ri = addend_reg,
        .rn = mul1_reg,
        .rm = mul2_reg,
        .size = size_enum,
    } });

    return try ctx.getValueFromReg(dst.toReg(), .vector);
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
    const src1_reg = try getValueRegVec(ctx, src1);
    const src2_reg = try getValueRegVec(ctx, src2);
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    try ctx.emit(Inst{ .vec_rrr = .{
        .op = op,
        .dst = dst,
        .rn = src1_reg,
        .rm = src2_reg,
        .size = size_enum,
    } });

    return try ctx.getValueFromReg(dst.toReg(), .vector);
}

/// vec_misc: Unary vector operation (VecMisc - 2 registers)
/// Emits vector miscellaneous operation: dst = op(src)
pub fn vec_misc(
    op: VecMisc2,
    src: lower_mod.Value,
    size_enum: VectorSize,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.Value {
    const src_reg = try getValueRegVec(ctx, src);
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    try ctx.emit(Inst{ .vec_misc = .{
        .op = op,
        .dst = dst,
        .rn = src_reg,
        .size = size_enum,
    } });

    return try ctx.getValueFromReg(dst.toReg(), .vector);
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
    const addend_reg = try getValueRegVec(ctx, addend);
    const mul1_reg = try getValueRegVec(ctx, multiplicand1);
    const mul2_reg = try getValueRegVec(ctx, multiplicand2);

    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    try ctx.emit(Inst{ .vec_fmla_elem = .{
        .op = op,
        .dst = dst,
        .ri = addend_reg,
        .rn = mul1_reg,
        .rm = mul2_reg,
        .size = size_enum,
        .idx = idx,
    } });

    return try ctx.getValueFromReg(dst.toReg(), .vector);
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
) !isle_types.ConsumesFlags {
    const rn_reg = try getValueRegFloat(ctx, rn);
    const rm_reg = try getValueRegFloat(ctx, rm);
    const dst = lower_mod.WritableVReg.allocVReg(.float, ctx);

    const aarch_cond = intccToCondCode(cond);

    const size: FpuOperandSize = if (ty.eql(Type.F32))
        .size32
    else
        .size64;

    return isle_types.ConsumesFlags.consumesFlagsReturnsReg(
        Inst{ .fcsel = .{
            .dst = dst,
            .src1 = rn_reg,
            .src2 = rm_reg,
            .cond = aarch_cond,
            .size = size,
        } },
        dst.toReg(),
    );
}

/// vec_csel: Vector conditional select for 128-bit vectors
pub fn vec_csel(
    cond: IntCC,
    rn: lower_mod.Value,
    rm: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !isle_types.ConsumesFlags {
    const rn_reg = try ctx.getValueReg(rn, .vector);
    const rm_reg = try ctx.getValueReg(rm, .vector);
    const dst = lower_mod.WritableVReg.allocVReg(.vector, ctx);

    const aarch_cond = intccToCondCode(cond);

    return isle_types.ConsumesFlags.consumesFlagsReturnsReg(
        Inst.VecCSel{ .rd = dst, .cond = aarch_cond, .rn = rn_reg, .rm = rm_reg },
        dst.toReg(),
    );
}

/// put_in_regs: Convert Value to ValueRegs
pub fn put_in_regs(
    val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const ty = try ctx.getValueType(val);

    if (ty.eql(Type.I128)) {
        if (ctx.func.dfg.valueDef(val)) |def| {
            if (def.inst()) |inst| {
                if (ctx.func.dfg.insts.get(inst)) |inst_data_ptr| {
                    switch (inst_data_ptr.*) {
                        .binary => |data| {
                            if (data.opcode == .iconcat) {
                                const lo = data.args[0];
                                const hi = data.args[1];
                                const lo_reg = try getValueReg(ctx, lo);
                                const hi_reg = try getValueReg(ctx, hi);
                                return lower_mod.ValueRegs.pair(lo_reg, hi_reg);
                            }
                        },
                        else => {},
                    }
                }
            }
        }

        // Fallback mapping used by the codegen pipeline for non-iconcat I128 producers.
        const lo_vreg = lower_mod.VReg.new(@intCast(val.index + lower_mod.Reg.PINNED_VREGS), .int);
        const hi_vreg = lower_mod.VReg.new(@intCast(val.index + lower_mod.Reg.PINNED_VREGS + 1), .int);
        return lower_mod.ValueRegs.pair(
            lower_mod.Reg.fromVReg(lo_vreg),
            lower_mod.Reg.fromVReg(hi_vreg),
        );
    } else {
        const class = typeToRegClass(ty);
        const vreg = try ctx.getValueReg(val, class);
        return lower_mod.ValueRegs.single(lower_mod.Reg.fromVReg(vreg));
    }
}

/// value_regs_get: Extract register from ValueRegs at index
pub fn value_regs_get(regs: lower_mod.ValueRegs, idx: u8) !Reg {
    if (regs.get(idx)) |r| return r;
    return error.NoMatch;
}

/// consumes_flags_two_csel: Consume flags with two CSELs for I128
pub fn consumes_flags_two_csel(
    cond: IntCC,
    rn_lo: Reg,
    rn_hi: Reg,
    rm_lo: Reg,
    rm_hi: Reg,
    ctx: *lower_mod.LowerCtx(Inst),
) !isle_types.ConsumesFlags {
    const dst_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    const dst_hi = lower_mod.WritableReg.allocReg(.int, ctx);

    const aarch_cond = intccToCondCode(cond);

    return isle_types.ConsumesFlags.consumesFlagsTwiceReturnsValueRegs(
        Inst{ .csel = .{
            .dst = dst_lo,
            .src1 = rn_lo,
            .src2 = rm_lo,
            .cond = aarch_cond,
            .size = .size64,
        } },
        Inst{ .csel = .{
            .dst = dst_hi,
            .src1 = rn_hi,
            .src2 = rm_hi,
            .cond = aarch_cond,
            .size = .size64,
        } },
        lower_mod.ValueRegs.pair(dst_lo.toReg(), dst_hi.toReg()),
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
    const ty = try ctx.getValueType(val);
    const src = lower_mod.Reg.fromVReg(try ctx.getValueReg(val, .int));

    // If already 32-bit, return as-is
    if (ty.bits() == 32) {
        return src;
    }

    if (ty.bits() > 32) return error.Unimplemented;

    // For smaller types, zero-extend to 32 bits.
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    switch (ty.bits()) {
        8 => try ctx.emit(Inst{ .zext8 = .{ .dst = dst, .src = src, .size = .size32 } }),
        16 => try ctx.emit(Inst{ .zext16 = .{ .dst = dst, .src = src, .size = .size32 } }),
        else => {
            const bits: u6 = @intCast(ty.bits());
            const mask: u64 = (@as(u64, 1) << bits) - 1;
            const imm = ImmLogic.maybeFromU64(mask, .size32) orelse return error.UnsupportedLogicalImmediate;
            try ctx.emit(Inst{ .and_imm = .{ .dst = dst, .src = src, .imm = imm } });
        },
    }

    return dst.toReg();
}

/// put_in_reg_zext64: Put value in register with 64-bit zero extension
/// put_in_reg_sext32: Put value in register with 32-bit sign extension
pub fn put_in_reg_sext32(
    val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Reg {
    const ty = try ctx.getValueType(val);
    const src = lower_mod.Reg.fromVReg(try ctx.getValueReg(val, .int));

    // If already 32-bit, return as-is
    if (ty.bits() == 32) {
        return src;
    }

    if (ty.bits() > 32) return error.Unimplemented;

    // For smaller types, sign-extend to 32 bits.
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    switch (ty.bits()) {
        8 => try ctx.emit(Inst{ .sxtb = .{ .dst = dst, .src = src, .dst_size = .size32 } }),
        16 => try ctx.emit(Inst{ .sxth = .{ .dst = dst, .src = src, .dst_size = .size32 } }),
        else => {
            const sh: u8 = @intCast(32 - ty.bits());
            try ctx.emit(Inst{ .lsl_imm = .{ .dst = dst, .src = src, .imm = sh, .size = .size32 } });
            try ctx.emit(Inst{ .asr_imm = .{ .dst = dst, .src = dst.toReg(), .imm = sh, .size = .size32 } });
        },
    }

    return dst.toReg();
}
pub fn put_in_reg_zext64(
    val: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Reg {
    const ty = try ctx.getValueType(val);
    const reg = try getValueReg(ctx, val);

    // If already 64-bit, return as-is
    if (ty.bits() == 64) {
        return reg;
    }

    if (ty.bits() > 32) return error.Unimplemented;

    // For smaller types, zero-extend to 64 bits.
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    if (ty.bits() == 32) {
        try ctx.emit(Inst{ .zext32 = .{ .dst = dst, .src = reg } });
        return dst.toReg();
    }

    switch (ty.bits()) {
        8 => try ctx.emit(Inst{ .zext8 = .{ .dst = dst, .src = reg, .size = .size32 } }),
        16 => try ctx.emit(Inst{ .zext16 = .{ .dst = dst, .src = reg, .size = .size32 } }),
        else => {
            const bits: u6 = @intCast(ty.bits());
            const mask: u64 = (@as(u64, 1) << bits) - 1;
            const imm = ImmLogic.maybeFromU64(mask, .size32) orelse return error.UnsupportedLogicalImmediate;
            try ctx.emit(Inst{ .and_imm = .{ .dst = dst, .src = reg, .imm = imm } });
        },
    }

    return dst.toReg();
}

/// cmp: Compare two registers and produce flags
pub fn cmp(
    ty: Type,
    rn: Reg,
    rm: Reg,
    _: *lower_mod.LowerCtx(Inst),
) !isle_types.ProducesFlags {
    const size: OperandSize = if (ty.bits() == 32) .size32 else .size64;

    return isle_types.ProducesFlags.producesFlagsSideEffect(
        Inst{ .cmp_rr = .{ .src1 = rn, .src2 = rm, .size = size } },
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
    recordRule("aarch64_ldr");
    const base = try getValueReg(ctx, addr);
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
    recordRule("aarch64_ldr_imm");
    const base = try getValueReg(ctx, base_val);
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
    recordRule("aarch64_ldr_reg");
    const base = try getValueReg(ctx, base_val);
    const offset = try getValueReg(ctx, offset_val);
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
    recordRule("aarch64_ldr_ext");
    const base = try getValueReg(ctx, base_val);
    const offset = try getValueReg(ctx, offset_val);
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
    recordRule("aarch64_ldr_shifted");
    const base = try getValueReg(ctx, base_val);
    const offset = try getValueReg(ctx, offset_val);
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
    recordRule("aarch64_ldr_pre");
    const base_vreg = try ctx.getValueReg(base_val, .int);
    const base = lower_mod.WritableReg.fromVReg(base_vreg);
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
    recordRule("aarch64_ldr_post");
    const base_vreg = try ctx.getValueReg(base_val, .int);
    const base = lower_mod.WritableReg.fromVReg(base_vreg);
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
    recordRule("aarch64_uload8x8");
    const addr = try getValueReg(ctx, addr_val);
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
            .src = tmp.toReg(),
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
    recordRule("aarch64_sload8x8");
    const addr = try getValueReg(ctx, addr_val);
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
            .src = tmp.toReg(),
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
    recordRule("aarch64_uload16x4");
    const addr = try getValueReg(ctx, addr_val);
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
            .src = tmp.toReg(),
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
    recordRule("aarch64_sload16x4");
    const addr = try getValueReg(ctx, addr_val);
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
            .src = tmp.toReg(),
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
    recordRule("aarch64_uload32x2");
    const addr = try getValueReg(ctx, addr_val);
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
            .src = tmp.toReg(),
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
    recordRule("aarch64_sload32x2");
    const addr = try getValueReg(ctx, addr_val);
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
            .src = tmp.toReg(),
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
    recordRule("aarch64_istore8");
    const base = try getValueReg(ctx, addr);
    const src = try getValueReg(ctx, val);

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
    recordRule("aarch64_istore16");
    const base = try getValueReg(ctx, addr);
    const src = try getValueReg(ctx, val);

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
    recordRule("aarch64_istore32");
    const base = try getValueReg(ctx, addr);
    const src = try getValueReg(ctx, val);

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
    recordRule("aarch64_str");
    const base = try getValueReg(ctx, addr);
    const src = try getValueReg(ctx, val);
    const ty = try ctx.getValueType(val);
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
    recordRule("aarch64_str_imm");
    const base = try getValueReg(ctx, base_val);
    const src = try getValueReg(ctx, val);
    const ty = try ctx.getValueType(val);
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
    recordRule("aarch64_str_reg");
    const base = try getValueReg(ctx, base_val);
    const offset = try getValueReg(ctx, offset_val);
    const src = try getValueReg(ctx, val);
    const ty = try ctx.getValueType(val);
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
    recordRule("aarch64_str_ext");
    const base = try getValueReg(ctx, base_val);
    const offset = try getValueReg(ctx, offset_val);
    const src = try getValueReg(ctx, val);
    const ty = try ctx.getValueType(val);
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
    recordRule("aarch64_str_shifted");
    const base = try getValueReg(ctx, base_val);
    const offset = try getValueReg(ctx, offset_val);
    const src = try getValueReg(ctx, val);
    const ty = try ctx.getValueType(val);
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
    recordRule("aarch64_str_pre");
    const base_vreg = try ctx.getValueReg(base_val, .int);
    const base = lower_mod.WritableReg.fromVReg(base_vreg);
    const src = try getValueReg(ctx, val);
    const ty = try ctx.getValueType(val);
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
    recordRule("aarch64_str_post");
    const base_vreg = try ctx.getValueReg(base_val, .int);
    const base = lower_mod.WritableReg.fromVReg(base_vreg);
    const src = try getValueReg(ctx, val);
    const ty = try ctx.getValueType(val);
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
    recordRule("aarch64_vldr");
    const base = try getValueReg(ctx, addr);
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
    recordRule("aarch64_vstr");
    const base = try getValueReg(ctx, addr);
    const src = try getValueRegVec(ctx, val);
    const ty = try ctx.getValueType(val);
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
    recordRule("aarch64_uload8");
    const base = try getValueReg(ctx, addr);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldrb = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .size64,
        },
    };
}

/// Load halfword (unsigned, zero-extend)
pub fn aarch64_uload16(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    recordRule("aarch64_uload16");
    const base = try getValueReg(ctx, addr);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldrh = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .size64,
        },
    };
}

/// Load word (unsigned, zero-extend to 64)
pub fn aarch64_uload32(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    recordRule("aarch64_uload32");
    const base = try getValueReg(ctx, addr);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldr = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .size32, // LDR Wd auto zero-extends to 64
        },
    };
}

/// Load doubleword (64-bit)
pub fn aarch64_uload64(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    recordRule("aarch64_uload64");
    const base = try getValueReg(ctx, addr);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldr = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .size64,
        },
    };
}

/// Load signed byte (sign-extend to 64)
pub fn aarch64_sload8(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    recordRule("aarch64_sload8");
    const base = try getValueReg(ctx, addr);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldrsb = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .size64,
        },
    };
}

/// Load signed halfword (sign-extend to 64)
pub fn aarch64_sload16(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    recordRule("aarch64_sload16");
    const base = try getValueReg(ctx, addr);
    const dst = lower_mod.WritableReg.allocReg(.int, ctx);
    return Inst{
        .ldrsh = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .size64,
        },
    };
}

/// Load signed word (sign-extend to 64)
pub fn aarch64_sload32(
    addr: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    recordRule("aarch64_sload32");
    const base = try getValueReg(ctx, addr);
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
    recordRule("aarch64_umul_overflow_i16");
    // Zero-extend both operands to 32-bit
    const a_ext = try put_in_reg_zext32(a, ctx);
    const b_ext = try put_in_reg_zext32(b, ctx);

    // Multiply: out = a_ext * b_ext
    const out_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .mul_rr = .{
            .dst = out_dst,
            .src1 = a_ext,
            .src2 = b_ext,
            .size = .size32,
        },
    });
    const out = out_dst.toReg();

    // Truncate to the input bitwidth; overflow iff trunc != full product.
    const trunc_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    switch (ty.bits()) {
        8 => try ctx.emit(Inst{ .zext8 = .{ .dst = trunc_dst, .src = out, .size = .size32 } }),
        16 => try ctx.emit(Inst{ .zext16 = .{ .dst = trunc_dst, .src = out, .size = .size32 } }),
        else => {
            if (ty.bits() >= 32) return error.Unimplemented;
            const bits: u6 = @intCast(ty.bits());
            const mask: u64 = (@as(u64, 1) << bits) - 1;
            const imm = ImmLogic.maybeFromU64(mask, .size32) orelse return error.UnsupportedLogicalImmediate;
            try ctx.emit(Inst{ .and_imm = .{ .dst = trunc_dst, .src = out, .imm = imm } });
        },
    }

    try ctx.emit(Inst{ .cmp_rr = .{
        .src1 = out,
        .src2 = trunc_dst.toReg(),
        .size = .size32,
    } });

    // Set overflow bit based on comparison
    const of_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = of_dst,
            .cond = intccToCondCode(.ne),
            .size = .size32,
        },
    });

    return lower_mod.ValueRegs.pair(trunc_dst.toReg(), of_dst.toReg());
}

/// Unsigned multiply overflow for I32
/// Strategy: UMULL (multiply to 64-bit), compare with UXTW extension
pub fn aarch64_umul_overflow_i32(
    a: lower_mod.Value,
    b: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    recordRule("aarch64_umul_overflow_i32");
    const a_reg = try getValueReg(ctx, a);
    const b_reg = try getValueReg(ctx, b);

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

    // Extend low 32 bits and compare with full 64-bit product.
    const ext_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .uxtw = .{
            .dst = ext_dst,
            .src = out,
        },
    });

    // Compare: if out != extended version, we overflowed
    try ctx.emit(Inst{
        .cmp_rr = .{
            .src1 = out,
            .src2 = ext_dst.toReg(),
            .size = .size64,
        },
    });

    const of_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = of_dst,
            .cond = intccToCondCode(.ne),
            .size = .size32,
        },
    });

    return lower_mod.ValueRegs.pair(ext_dst.toReg(), of_dst.toReg());
}

/// Unsigned multiply overflow for I64
/// Strategy: MUL + UMULH, check if high bits are non-zero
pub fn aarch64_umul_overflow_i64(
    a: lower_mod.Value,
    b: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    recordRule("aarch64_umul_overflow_i64");
    const a_reg = try getValueReg(ctx, a);
    const b_reg = try getValueReg(ctx, b);

    // MUL: low 64 bits
    const out_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .mul_rr = .{
            .dst = out_dst,
            .src1 = a_reg,
            .src2 = b_reg,
            .size = .size64,
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
    const imm0: Imm12 = .{ .bits = 0, .shift12 = false };
    try ctx.emit(Inst{
        .cmp_imm = .{
            .src = high_dst.toReg(),
            .imm = imm0,
            .size = .size64,
        },
    });

    const of_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = of_dst,
            .cond = intccToCondCode(.ne),
            .size = .size32,
        },
    });

    return lower_mod.ValueRegs.pair(out_dst.toReg(), of_dst.toReg());
}

/// Signed multiply overflow for I16
/// Strategy: Sign-extend to 32-bit, multiply, compare result with itself extended
pub fn aarch64_smul_overflow_i16(
    ty: Type,
    a: lower_mod.Value,
    b: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    recordRule("aarch64_smul_overflow_i16");
    // Sign-extend both operands to 32-bit
    const a_ext = try put_in_reg_sext32(a, ctx);
    const b_ext = try put_in_reg_sext32(b, ctx);

    // Multiply
    const out_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .mul_rr = .{
            .dst = out_dst,
            .src1 = a_ext,
            .src2 = b_ext,
            .size = .size32,
        },
    });
    const out = out_dst.toReg();

    // Truncate to the input bitwidth; overflow iff sign-extended trunc != full product.
    const trunc_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    switch (ty.bits()) {
        8 => try ctx.emit(Inst{ .zext8 = .{ .dst = trunc_dst, .src = out, .size = .size32 } }),
        16 => try ctx.emit(Inst{ .zext16 = .{ .dst = trunc_dst, .src = out, .size = .size32 } }),
        else => {
            if (ty.bits() >= 32) return error.Unimplemented;
            const bits: u6 = @intCast(ty.bits());
            const mask: u64 = (@as(u64, 1) << bits) - 1;
            const imm = ImmLogic.maybeFromU64(mask, .size32) orelse return error.UnsupportedLogicalImmediate;
            try ctx.emit(Inst{ .and_imm = .{ .dst = trunc_dst, .src = out, .imm = imm } });
        },
    }

    const sext_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    switch (ty.bits()) {
        8 => try ctx.emit(Inst{ .sxtb = .{ .dst = sext_dst, .src = trunc_dst.toReg(), .dst_size = .size32 } }),
        16 => try ctx.emit(Inst{ .sxth = .{ .dst = sext_dst, .src = trunc_dst.toReg(), .dst_size = .size32 } }),
        else => return error.Unimplemented,
    }

    try ctx.emit(Inst{ .cmp_rr = .{
        .src1 = out,
        .src2 = sext_dst.toReg(),
        .size = .size32,
    } });

    const of_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = of_dst,
            .cond = intccToCondCode(.ne),
            .size = .size32,
        },
    });

    return lower_mod.ValueRegs.pair(trunc_dst.toReg(), of_dst.toReg());
}

/// Signed multiply overflow for I32
/// Strategy: SMULL (multiply to 64-bit), compare with SXTW extension
pub fn aarch64_smul_overflow_i32(
    a: lower_mod.Value,
    b: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    recordRule("aarch64_smul_overflow_i32");
    const a_reg = try getValueReg(ctx, a);
    const b_reg = try getValueReg(ctx, b);

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

    const sext_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .sxtw = .{ .dst = sext_dst, .src = out } });

    try ctx.emit(Inst{ .cmp_rr = .{
        .src1 = out,
        .src2 = sext_dst.toReg(),
        .size = .size64,
    } });

    const of_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = of_dst,
            .cond = intccToCondCode(.ne),
            .size = .size32,
        },
    });

    const prod_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .uxtw = .{ .dst = prod_dst, .src = out } });

    return lower_mod.ValueRegs.pair(prod_dst.toReg(), of_dst.toReg());
}

/// Signed multiply overflow for I64
/// Strategy: MUL + SMULH, compare high bits with sign-extended result
pub fn aarch64_smul_overflow_i64(
    a: lower_mod.Value,
    b: lower_mod.Value,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    recordRule("aarch64_smul_overflow_i64");
    const a_reg = try getValueReg(ctx, a);
    const b_reg = try getValueReg(ctx, b);

    // MUL: low 64 bits
    const out_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .mul_rr = .{
            .dst = out_dst,
            .src1 = a_reg,
            .src2 = b_reg,
            .size = .size64,
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
            .imm = 63,
            .size = .size64,
        },
    });

    // Compare high bits with sign extension
    // If they differ, we overflowed
    try ctx.emit(Inst{ .cmp_rr = .{
        .src1 = high_dst.toReg(),
        .src2 = sign_dst.toReg(),
        .size = .size64,
    } });

    const of_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cset = .{
            .dst = of_dst,
            .cond = intccToCondCode(.ne),
            .size = .size32,
        },
    });

    return lower_mod.ValueRegs.pair(out_dst.toReg(), of_dst.toReg());
}

// I128 arithmetic helpers

/// Sign-extend a 64-bit scalar to an I128 register pair.
/// Low half is reused, high half is arithmetic shift-right by 63.
pub fn lower_sextend128(
    val: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = val.get(0) orelse return error.NoMatch;

    const out_hi = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .asr_imm = .{
            .dst = out_hi,
            .src = lo,
            .imm = 63,
            .size = .size64,
        },
    });

    return lower_mod.ValueRegs.pair(lo, out_hi.toReg());
}

/// Zero-extend a 64-bit scalar to an I128 register pair.
/// Low half is reused; high half is XZR.
pub fn lower_uextend128(
    val: lower_mod.ValueRegs,
    _: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = val.get(0) orelse return error.NoMatch;
    const zero = Reg.fromPReg(PReg.new(.int, 31));
    return lower_mod.ValueRegs.pair(lo, zero);
}

/// Negate an I128 value encoded as (lo, hi) register pair.
/// Uses two's-complement subtraction with carry propagation.
pub fn lower_ineg128(
    val: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = val.get(0) orelse return error.NoMatch;
    const hi = val.get(1) orelse return error.NoMatch;
    const zero = Reg.fromPReg(PReg.new(.int, 31));

    const out_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .subs_rr = .{
        .dst = out_lo,
        .src1 = zero,
        .src2 = lo,
        .size = .size64,
    } });

    const out_hi = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .sbcs = .{
        .dst = out_hi,
        .src1 = zero,
        .src2 = hi,
        .size = .size64,
    } });

    return lower_mod.ValueRegs.pair(out_lo.toReg(), out_hi.toReg());
}

/// Absolute value for I128 register pair.
/// sign = hi >> 63; result = (x ^ sign) - sign
pub fn lower_iabs128(
    val: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = val.get(0) orelse return error.NoMatch;
    const hi = val.get(1) orelse return error.NoMatch;

    const sign_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .asr_imm = .{
            .dst = sign_dst,
            .src = hi,
            .imm = 63,
            .size = .size64,
        },
    });
    const sign = sign_dst.toReg();

    const lo_xor_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .eor_rr = .{
        .dst = lo_xor_dst,
        .src1 = lo,
        .src2 = sign,
        .size = .size64,
    } });
    const lo_xor = lo_xor_dst.toReg();

    const hi_xor_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .eor_rr = .{
        .dst = hi_xor_dst,
        .src1 = hi,
        .src2 = sign,
        .size = .size64,
    } });
    const hi_xor = hi_xor_dst.toReg();

    const out_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .subs_rr = .{
        .dst = out_lo,
        .src1 = lo_xor,
        .src2 = sign,
        .size = .size64,
    } });

    const out_hi = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .sbcs = .{
        .dst = out_hi,
        .src1 = hi_xor,
        .src2 = sign,
        .size = .size64,
    } });

    return lower_mod.ValueRegs.pair(out_lo.toReg(), out_hi.toReg());
}

/// Bit-reverse a 128-bit value encoded as (lo, hi) register pair.
/// Reverses bits in each half and swaps halves.
pub fn lower_bitrev128(
    val: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = val.get(0) orelse return error.NoMatch;
    const hi = val.get(1) orelse return error.NoMatch;

    const lo_rev_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .rbit = .{
            .dst = lo_rev_dst,
            .src = lo,
            .size = .size64,
        },
    });

    const hi_rev_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .rbit = .{
            .dst = hi_rev_dst,
            .src = hi,
            .size = .size64,
        },
    });

    return lower_mod.ValueRegs.pair(hi_rev_dst.toReg(), lo_rev_dst.toReg());
}

/// Byte-swap a 128-bit value encoded as (lo, hi) register pair.
/// Reverses bytes in each half and swaps halves.
pub fn lower_bswap128(
    val: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = val.get(0) orelse return error.NoMatch;
    const hi = val.get(1) orelse return error.NoMatch;

    const lo_rev_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .rev64 = .{
            .dst = lo_rev_dst,
            .src = lo,
        },
    });

    const hi_rev_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .rev64 = .{
            .dst = hi_rev_dst,
            .src = hi,
        },
    });

    return lower_mod.ValueRegs.pair(hi_rev_dst.toReg(), lo_rev_dst.toReg());
}

/// Add two I128 values encoded as (lo, hi) register pairs.
/// Emits ADDS for low half and ADCS for high half to propagate carry.
pub fn lower_iadd128(
    lhs: lower_mod.ValueRegs,
    rhs: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lhs_lo = lhs.get(0) orelse return error.NoMatch;
    const lhs_hi = lhs.get(1) orelse return error.NoMatch;
    const rhs_lo = rhs.get(0) orelse return error.NoMatch;
    const rhs_hi = rhs.get(1) orelse return error.NoMatch;

    const out_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .adds_rr = .{
        .dst = out_lo,
        .src1 = lhs_lo,
        .src2 = rhs_lo,
        .size = .size64,
    } });

    const out_hi = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .adcs = .{
        .dst = out_hi,
        .src1 = lhs_hi,
        .src2 = rhs_hi,
        .size = .size64,
    } });

    return lower_mod.ValueRegs.pair(out_lo.toReg(), out_hi.toReg());
}

/// Subtract two I128 values encoded as (lo, hi) register pairs.
/// Emits SUBS for low half and SBCS for high half to propagate borrow.
pub fn lower_isub128(
    lhs: lower_mod.ValueRegs,
    rhs: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lhs_lo = lhs.get(0) orelse return error.NoMatch;
    const lhs_hi = lhs.get(1) orelse return error.NoMatch;
    const rhs_lo = rhs.get(0) orelse return error.NoMatch;
    const rhs_hi = rhs.get(1) orelse return error.NoMatch;

    const out_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .subs_rr = .{
        .dst = out_lo,
        .src1 = lhs_lo,
        .src2 = rhs_lo,
        .size = .size64,
    } });

    const out_hi = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .sbcs = .{
        .dst = out_hi,
        .src1 = lhs_hi,
        .src2 = rhs_hi,
        .size = .size64,
    } });

    return lower_mod.ValueRegs.pair(out_lo.toReg(), out_hi.toReg());
}

/// Multiply two I128 values encoded as (lo, hi) register pairs.
/// Computes the low 128 bits of the product with:
/// lo = x_lo * y_lo
/// hi = umulh(x_lo, y_lo) + x_lo*y_hi + x_hi*y_lo
pub fn lower_imul128(
    lhs: lower_mod.ValueRegs,
    rhs: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lhs_lo = lhs.get(0) orelse return error.NoMatch;
    const lhs_hi = lhs.get(1) orelse return error.NoMatch;
    const rhs_lo = rhs.get(0) orelse return error.NoMatch;
    const rhs_hi = rhs.get(1) orelse return error.NoMatch;

    const out_hi = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .umulh = .{
        .dst = out_hi,
        .src1 = lhs_lo,
        .src2 = rhs_lo,
    } });

    try ctx.emit(Inst{ .madd = .{
        .dst = out_hi,
        .src1 = lhs_lo,
        .src2 = rhs_hi,
        .addend = out_hi.toReg(),
        .size = .size64,
    } });

    try ctx.emit(Inst{ .madd = .{
        .dst = out_hi,
        .src1 = lhs_hi,
        .src2 = rhs_lo,
        .addend = out_hi.toReg(),
        .size = .size64,
    } });

    const out_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .mul_rr = .{
        .dst = out_lo,
        .src1 = lhs_lo,
        .src2 = rhs_lo,
        .size = .size64,
    } });

    return lower_mod.ValueRegs.pair(out_lo.toReg(), out_hi.toReg());
}

/// Rotate-right for I128 register pairs.
/// Shift amount is masked to 0..127 and uses variable 64-bit shifts plus lane swap.
pub fn lower_rotr128(
    val: lower_mod.ValueRegs,
    amt: Reg,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = val.get(0) orelse return error.NoMatch;
    const hi = val.get(1) orelse return error.NoMatch;

    const imm127 = ImmLogic.maybeFromU64(127, .size64) orelse return error.UnsupportedLogicalImmediate;
    const imm63 = ImmLogic.maybeFromU64(63, .size64) orelse return error.UnsupportedLogicalImmediate;
    const imm0: Imm12 = .{ .bits = 0, .shift12 = false };

    const amt128_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .and_imm = .{
        .dst = amt128_dst,
        .src = amt,
        .imm = imm127,
    } });
    const amt128 = amt128_dst.toReg();

    const sh_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .and_imm = .{
        .dst = sh_dst,
        .src = amt128,
        .imm = imm63,
    } });
    const sh = sh_dst.toReg();

    const neg_sh_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .neg = .{
        .dst = neg_sh_dst,
        .src = sh,
        .size = .size64,
    } });

    const inv_sh_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .and_imm = .{
        .dst = inv_sh_dst,
        .src = neg_sh_dst.toReg(),
        .imm = imm63,
    } });
    const inv_sh = inv_sh_dst.toReg();

    const lo_shr_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .lsr_rr = .{
        .dst = lo_shr_dst,
        .src1 = lo,
        .src2 = sh,
        .size = .size64,
    } });

    const hi_shl_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .lsl_rr = .{
        .dst = hi_shl_dst,
        .src1 = hi,
        .src2 = inv_sh,
        .size = .size64,
    } });

    const lo_mix_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .orr_rr = .{
        .dst = lo_mix_dst,
        .src1 = lo_shr_dst.toReg(),
        .src2 = hi_shl_dst.toReg(),
        .size = .size64,
    } });
    const lo_mix = lo_mix_dst.toReg();

    const hi_shr_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .lsr_rr = .{
        .dst = hi_shr_dst,
        .src1 = hi,
        .src2 = sh,
        .size = .size64,
    } });

    const lo_shl_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .lsl_rr = .{
        .dst = lo_shl_dst,
        .src1 = lo,
        .src2 = inv_sh,
        .size = .size64,
    } });

    const hi_mix_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .orr_rr = .{
        .dst = hi_mix_dst,
        .src1 = hi_shr_dst.toReg(),
        .src2 = lo_shl_dst.toReg(),
        .size = .size64,
    } });
    const hi_mix = hi_mix_dst.toReg();

    const swap_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .lsr_imm = .{
        .dst = swap_dst,
        .src = amt128,
        .imm = 6,
        .size = .size64,
    } });
    const swap = swap_dst.toReg();

    try ctx.emit(Inst{ .cmp_imm = .{
        .src = swap,
        .imm = imm0,
        .size = .size64,
    } });

    const out_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .csel = .{
        .dst = out_lo,
        .src1 = hi_mix,
        .src2 = lo_mix,
        .cond = .ne,
        .size = .size64,
    } });

    const out_hi = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .csel = .{
        .dst = out_hi,
        .src1 = lo_mix,
        .src2 = hi_mix,
        .cond = .ne,
        .size = .size64,
    } });

    return lower_mod.ValueRegs.pair(out_lo.toReg(), out_hi.toReg());
}

/// Rotate-left for I128 register pairs.
/// Implemented as rotate-right by (-amt mod 128).
pub fn lower_rotl128(
    val: lower_mod.ValueRegs,
    amt: Reg,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const imm127 = ImmLogic.maybeFromU64(127, .size64) orelse return error.UnsupportedLogicalImmediate;

    const amt128_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .and_imm = .{
        .dst = amt128_dst,
        .src = amt,
        .imm = imm127,
    } });

    const neg_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .neg = .{
        .dst = neg_dst,
        .src = amt128_dst.toReg(),
        .size = .size64,
    } });

    const rotr_amt_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .and_imm = .{
        .dst = rotr_amt_dst,
        .src = neg_dst.toReg(),
        .imm = imm127,
    } });

    return lower_rotr128(val, rotr_amt_dst.toReg(), ctx);
}

/// Bitwise AND for I128 register pairs.
pub fn lower_band128(
    lhs: lower_mod.ValueRegs,
    rhs: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lhs_lo = lhs.get(0) orelse return error.NoMatch;
    const lhs_hi = lhs.get(1) orelse return error.NoMatch;
    const rhs_lo = rhs.get(0) orelse return error.NoMatch;
    const rhs_hi = rhs.get(1) orelse return error.NoMatch;

    const out_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .and_rr = .{
        .dst = out_lo,
        .src1 = lhs_lo,
        .src2 = rhs_lo,
        .size = .size64,
    } });

    const out_hi = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .and_rr = .{
        .dst = out_hi,
        .src1 = lhs_hi,
        .src2 = rhs_hi,
        .size = .size64,
    } });

    return lower_mod.ValueRegs.pair(out_lo.toReg(), out_hi.toReg());
}

/// Bitwise OR for I128 register pairs.
pub fn lower_bor128(
    lhs: lower_mod.ValueRegs,
    rhs: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lhs_lo = lhs.get(0) orelse return error.NoMatch;
    const lhs_hi = lhs.get(1) orelse return error.NoMatch;
    const rhs_lo = rhs.get(0) orelse return error.NoMatch;
    const rhs_hi = rhs.get(1) orelse return error.NoMatch;

    const out_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .orr_rr = .{
        .dst = out_lo,
        .src1 = lhs_lo,
        .src2 = rhs_lo,
        .size = .size64,
    } });

    const out_hi = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .orr_rr = .{
        .dst = out_hi,
        .src1 = lhs_hi,
        .src2 = rhs_hi,
        .size = .size64,
    } });

    return lower_mod.ValueRegs.pair(out_lo.toReg(), out_hi.toReg());
}

/// Bitwise XOR for I128 register pairs.
pub fn lower_bxor128(
    lhs: lower_mod.ValueRegs,
    rhs: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lhs_lo = lhs.get(0) orelse return error.NoMatch;
    const lhs_hi = lhs.get(1) orelse return error.NoMatch;
    const rhs_lo = rhs.get(0) orelse return error.NoMatch;
    const rhs_hi = rhs.get(1) orelse return error.NoMatch;

    const out_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .eor_rr = .{
        .dst = out_lo,
        .src1 = lhs_lo,
        .src2 = rhs_lo,
        .size = .size64,
    } });

    const out_hi = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .eor_rr = .{
        .dst = out_hi,
        .src1 = lhs_hi,
        .src2 = rhs_hi,
        .size = .size64,
    } });

    return lower_mod.ValueRegs.pair(out_lo.toReg(), out_hi.toReg());
}

/// Bitwise NOT for I128 register pairs.
pub fn lower_bnot128(
    val: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = val.get(0) orelse return error.NoMatch;
    const hi = val.get(1) orelse return error.NoMatch;

    const out_lo = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .mvn_rr = .{
        .dst = out_lo,
        .src = lo,
        .size = .size64,
    } });

    const out_hi = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{ .mvn_rr = .{
        .dst = out_hi,
        .src = hi,
        .size = .size64,
    } });

    return lower_mod.ValueRegs.pair(out_lo.toReg(), out_hi.toReg());
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
    const hi = val.get(1) orelse return error.NoMatch;
    const lo = val.get(0) orelse return error.NoMatch;

    // CLZ on both halves
    const hi_clz_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .clz = .{
            .dst = hi_clz_dst,
            .src = hi,
            .size = .size64,
        },
    });
    const hi_clz = hi_clz_dst.toReg();

    const lo_clz_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .clz = .{
            .dst = lo_clz_dst,
            .src = lo,
            .size = .size64,
        },
    });
    const lo_clz = lo_clz_dst.toReg();

    // LSR tmp, hi_clz, #6 (shift right by 6 to get 0 or 1)
    const tmp_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .lsr_imm = .{
            .dst = tmp_dst,
            .src = hi_clz,
            .imm = 6,
            .size = .size64,
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
            .addend = hi_clz,
            .size = .size64,
        },
    });

    const zero = Reg.fromPReg(PReg.new(.int, 31));
    return lower_mod.ValueRegs.pair(result_dst.toReg(), zero);
}

/// Count trailing zeros for I128.
/// Algorithm:
/// - ctz(x) = clz(rbit(x)) for each 64-bit half.
/// - If lo != 0: result = ctz(lo)
/// - Else: result = 64 + ctz(hi)
pub fn lower_ctz128(
    val: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = val.get(0) orelse return error.NoMatch;
    const hi = val.get(1) orelse return error.NoMatch;

    const lo_rbit_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .rbit = .{
            .dst = lo_rbit_dst,
            .src = lo,
            .size = .size64,
        },
    });
    const lo_rbit = lo_rbit_dst.toReg();

    const lo_ctz_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .clz = .{
            .dst = lo_ctz_dst,
            .src = lo_rbit,
            .size = .size64,
        },
    });
    const lo_ctz = lo_ctz_dst.toReg();

    const hi_rbit_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .rbit = .{
            .dst = hi_rbit_dst,
            .src = hi,
            .size = .size64,
        },
    });
    const hi_rbit = hi_rbit_dst.toReg();

    const hi_ctz_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .clz = .{
            .dst = hi_ctz_dst,
            .src = hi_rbit,
            .size = .size64,
        },
    });
    const hi_ctz = hi_ctz_dst.toReg();

    const hi_plus_64_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .add_imm = .{
            .dst = hi_plus_64_dst,
            .src = hi_ctz,
            .imm = 64,
            .size = .size64,
        },
    });
    const hi_plus_64 = hi_plus_64_dst.toReg();

    const zero_imm = Imm12.maybeFromU64(0) orelse return error.InvalidImmediate;
    try ctx.emit(Inst{
        .cmp_imm = .{
            .src = lo,
            .imm = zero_imm,
            .size = .size64,
        },
    });

    const result_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .csel = .{
            .dst = result_dst,
            .cond = intccToCondCode(.eq),
            .src1 = hi_plus_64,
            .src2 = lo_ctz,
            .size = .size64,
        },
    });

    const zero = Reg.fromPReg(PReg.new(.int, 31));
    return lower_mod.ValueRegs.pair(result_dst.toReg(), zero);
}

/// Count leading sign bits for I128
/// Complex algorithm from Cranelift - counts consecutive sign bits
pub fn lower_cls128(
    val: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = val.get(0) orelse return error.NoMatch;
    const hi = val.get(1) orelse return error.NoMatch;

    // CLS on both halves
    const lo_cls_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cls = .{
            .dst = lo_cls_dst,
            .src = lo,
            .size = .size64,
        },
    });
    const lo_cls = lo_cls_dst.toReg();

    const hi_cls_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .cls = .{
            .dst = hi_cls_dst,
            .src = hi,
            .size = .size64,
        },
    });
    const hi_cls = hi_cls_dst.toReg();

    // EON sign_eq_eon, hi, lo (XOR with NOT)
    const sign_eq_eon_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .eon_rr = .{
            .dst = sign_eq_eon_dst,
            .src1 = hi,
            .src2 = lo,
            .size = .size64,
        },
    });
    const sign_eq_eon = sign_eq_eon_dst.toReg();

    // LSR sign_eq, sign_eq_eon, #63
    const sign_eq_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .lsr_imm = .{
            .dst = sign_eq_dst,
            .src = sign_eq_eon,
            .imm = 63,
            .size = .size64,
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
            .addend = sign_eq,
            .size = .size64,
        },
    });
    const lo_sign_bits = lo_sign_bits_dst.toReg();

    // CMP hi_cls, #63
    const imm63 = Imm12.maybeFromU64(63) orelse return error.InvalidImmediate;
    try ctx.emit(Inst{
        .cmp_imm = .{
            .src = hi_cls,
            .imm = imm63,
            .size = .size64,
        },
    });

    // CSEL maybe_lo, lo_sign_bits, xzr, eq
    const maybe_lo_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .csel = .{
            .dst = maybe_lo_dst,
            .cond = intccToCondCode(.eq),
            .src1 = lo_sign_bits,
            .src2 = Reg.fromPReg(PReg.new(.int, 31)),
            .size = .size64,
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
            .size = .size64,
        },
    });

    const zero = Reg.fromPReg(PReg.new(.int, 31));
    return lower_mod.ValueRegs.pair(result_dst.toReg(), zero);
}

/// Population count for I128
/// Move both halves to vector, use CNT, sum all bytes
pub fn lower_popcnt128(
    val: lower_mod.ValueRegs,
    ctx: *lower_mod.LowerCtx(Inst),
) !lower_mod.ValueRegs {
    const lo = val.get(0) orelse return error.NoMatch;
    const hi = val.get(1) orelse return error.NoMatch;

    // Move lo to FPU (D register, lower half of Q)
    const tmp_half_dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    try ctx.emit(Inst{
        .fmov_from_gpr = .{
            .dst = tmp_half_dst,
            .src = lo,
            .size = .size64,
        },
    });
    const tmp_half = tmp_half_dst.toReg();

    // Insert hi into upper half to make full 128-bit vector
    const tmp_dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    try ctx.emit(Inst{
        .vec_insert_lane = .{
            .dst = tmp_dst,
            .vec = tmp_half,
            .src = hi,
            .lane = 1,
            .size = .size64x2,
        },
    });
    const tmp = tmp_dst.toReg();

    // CNT (count bits in each byte)
    const nbits_dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    try ctx.emit(Inst{
        .vec_misc = .{
            .op = .Cnt,
            .dst = nbits_dst,
            .rn = tmp,
            .size = .V16B,
        },
    });
    const nbits = nbits_dst.toReg();

    // ADDV (sum all bytes across vector)
    const added_dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    try ctx.emit(Inst{
        .vec_addv = .{
            .dst = added_dst,
            .src = nbits,
            .size = .size8x16,
        },
    });
    const added = added_dst.toReg();

    // Move result back to GPR
    const result_dst = lower_mod.WritableReg.allocReg(.int, ctx);
    try ctx.emit(Inst{
        .fmov_to_gpr = .{
            .dst = result_dst,
            .src = added,
            .size = .size64,
        },
    });

    const zero = Reg.fromPReg(PReg.new(.int, 31));
    return lower_mod.ValueRegs.pair(result_dst.toReg(), zero);
}

/// Vector shift by immediate
pub fn aarch64_vec_shift_imm(
    op: VecShiftImmOp,
    imm: u8,
    src: lower_mod.Value,
    size: VectorSize,
    ctx: *lower_mod.LowerCtx(Inst),
) !Inst {
    recordRule("aarch64_vec_shift_imm");
    const src_reg = try getValueRegVec(ctx, src);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = vectorSizeToElemSize(size);
    return Inst{
        .vec_shift_imm = .{
            .op = op,
            .dst = dst,
            .rn = src_reg,
            .size = elem_size,
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
    recordRule("aarch64_vec_add");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: VecElemSize = switch (size) {
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
    recordRule("aarch64_vec_sub");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: VecElemSize = switch (size) {
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
    recordRule("aarch64_vec_mul");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: VecElemSize = switch (size) {
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

/// Vector SDOT: signed dot product (3-operand accumulating)
/// SDOT Vd.4S, Vn.16B, Vm.16B - dst[i] += src1[4*i:4*i+3] · src2[4*i:4*i+3]
/// Requires FEAT_DotProd
pub fn aarch64_vec_sdot(acc: lower_mod.Value, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_vec_sdot");
    const acc_reg = try getValueReg(ctx, acc);
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    // Emit mov to copy accumulator to dst (3-operand form requires explicit copy)
    try ctx.emit(Inst{ .fmov = .{
        .dst = dst,
        .src = acc_reg,
        .size = .size128,
    } });

    return Inst{ .vec_sdot = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
    } };
}

/// Vector UDOT: unsigned dot product (3-operand accumulating)
/// UDOT Vd.4S, Vn.16B, Vm.16B - dst[i] += src1[4*i:4*i+3] · src2[4*i:4*i+3]
/// Requires FEAT_DotProd
pub fn aarch64_vec_udot(acc: lower_mod.Value, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_vec_udot");
    const acc_reg = try getValueReg(ctx, acc);
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    // Emit mov to copy accumulator to dst (3-operand form requires explicit copy)
    try ctx.emit(Inst{ .fmov = .{
        .dst = dst,
        .src = acc_reg,
        .size = .size128,
    } });

    return Inst{ .vec_udot = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
    } };
}

/// Vector FADD: element-wise FP addition
pub fn aarch64_vec_fadd(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_vec_fadd");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: VecElemSize = switch (size) {
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
    recordRule("aarch64_vec_fsub");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: VecElemSize = switch (size) {
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
    recordRule("aarch64_vec_fmul");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: VecElemSize = switch (size) {
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
    recordRule("aarch64_vec_fdiv");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: VecElemSize = switch (size) {
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
    recordRule("aarch64_vec_smin");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = vectorSizeToElemSize(size);

    return Inst{ .vec_smin = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

pub fn aarch64_vec_smax(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_vec_smax");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = vectorSizeToElemSize(size);

    return Inst{ .vec_smax = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

pub fn aarch64_vec_umin(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_vec_umin");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = vectorSizeToElemSize(size);

    return Inst{ .vec_umin = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

pub fn aarch64_vec_umax(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_vec_umax");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = vectorSizeToElemSize(size);

    return Inst{ .vec_umax = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

pub fn aarch64_vec_fmin(size: VectorSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_vec_fmin");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: VecElemSize = switch (size) {
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
    recordRule("aarch64_vec_fmax");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);

    const elem_size: VecElemSize = switch (size) {
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
    recordRule("aarch64_snarrow");
    const x_reg = try getValueReg(ctx, x);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = vectorSizeToElemSize(size);

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
    recordRule("aarch64_unarrow");
    const x_reg = try getValueReg(ctx, x);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = vectorSizeToElemSize(size);

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
    recordRule("aarch64_uunarrow");
    const x_reg = try getValueReg(ctx, x);
    const dst = lower_mod.WritableReg.allocReg(.vector, ctx);
    const elem_size = vectorSizeToElemSize(size);

    return Inst{ .vec_uqxtn = .{
        .dst = dst,
        .src = x_reg,
        .size = elem_size,
        .high = false,
    } };
}

/// Constructor: get_frame_pointer - Get frame pointer (X29/FP)
pub fn aarch64_get_frame_pointer(ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_get_frame_pointer");
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
    recordRule("aarch64_get_stack_pointer");
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
    recordRule("aarch64_get_return_address");
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
    recordRule("aarch64_ld1r");
    const base_reg = try getValueReg(ctx, addr);

    const size = try tyToVecElemSize(ty);

    return Inst{ .ld1r = .{
        .dst = lower_mod.WritableVReg.allocVReg(.vector, ctx),
        .base = base_reg,
        .size = size,
    } };
}

/// Floating-point constant constructors
/// Check if f32 can be encoded as FMOV immediate (VFPExpandImm).
/// Valid values: ±n/16 × 2^r for n=16..31, r=-3..4
/// NOTE: 0.0 cannot be encoded; use constant pool or MOVI.
fn canEncodeFMovImmF32(value: f32) bool {
    const bits: u32 = @bitCast(value);
    const exp = (bits >> 23) & 0xFF;
    const frac = bits & 0x7FFFFF;

    // Low 19 mantissa bits must be zero
    if (frac & 0x7FFFF != 0) return false;

    // Exponent in range 124-131
    if (exp < 124 or exp > 131) return false;

    // exp[7:6] must be 01 or 10
    const exp_hi = (exp >> 6) & 0x3;
    return exp_hi == 0b01 or exp_hi == 0b10;
}

/// Check if f64 can be encoded as FMOV immediate (VFPExpandImm).
/// Valid values: ±n/16 × 2^r for n=16..31, r=-3..4
/// NOTE: 0.0 cannot be encoded; use constant pool or MOVI.
fn canEncodeFMovImmF64(value: f64) bool {
    const bits: u64 = @bitCast(value);
    const exp = (bits >> 52) & 0x7FF;
    const frac = bits & 0xFFFFFFFFFFFFF;

    // Low 48 mantissa bits must be zero
    if (frac & 0xFFFFFFFFFFFF != 0) return false;

    // Exponent in range 1020-1027
    if (exp < 1020 or exp > 1027) return false;

    // exp[10:9] must be 01 or 10
    const exp_hi = (exp >> 9) & 0x3;
    return exp_hi == 0b01 or exp_hi == 0b10;
}

/// Constructor: aarch64_f32const - Load 32-bit float constant
/// Uses FMOV immediate if possible, otherwise loads from constant pool
pub fn aarch64_f32const(value: f32, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_f32const");
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
    recordRule("aarch64_f64const");
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
pub fn nzcv_for_ccmp_and_fail(cond: hoist.aarch64_inst.CondCode) u4 {
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

// ==================== SVE Constructors ====================

/// SVE ADD: element-wise addition on scalable vectors
pub fn aarch64_sve_add(size: SveElemSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_sve_add");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.scalable_vector, ctx);

    const elem_size: Inst.SveElemSize = switch (size) {
        .B => .B,
        .H => .H,
        .S => .S,
        .D => .D,
    };

    return Inst{ .sve_add = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

/// SVE SUB: element-wise subtraction on scalable vectors
pub fn aarch64_sve_sub(size: SveElemSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_sve_sub");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.scalable_vector, ctx);

    const elem_size: Inst.SveElemSize = switch (size) {
        .B => .B,
        .H => .H,
        .S => .S,
        .D => .D,
    };

    return Inst{ .sve_sub = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

/// SVE MUL: element-wise multiplication on scalable vectors
pub fn aarch64_sve_mul(size: SveElemSize, x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_sve_mul");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.scalable_vector, ctx);

    const elem_size: Inst.SveElemSize = switch (size) {
        .B => .B,
        .H => .H,
        .S => .S,
        .D => .D,
    };

    return Inst{ .sve_mul = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
        .size = elem_size,
    } };
}

/// SVE AND: bitwise AND on scalable vectors (unpredicated)
pub fn aarch64_sve_and(x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_sve_and");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.scalable_vector, ctx);

    return Inst{ .sve_and = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
    } };
}

/// SVE ORR: bitwise OR on scalable vectors (unpredicated)
pub fn aarch64_sve_orr(x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_sve_orr");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.scalable_vector, ctx);

    return Inst{ .sve_orr = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
    } };
}

/// SVE EOR: bitwise XOR on scalable vectors (unpredicated)
pub fn aarch64_sve_eor(x: lower_mod.Value, y: lower_mod.Value, ctx: *lower_mod.LowerCtx(Inst)) !Inst {
    recordRule("aarch64_sve_eor");
    const x_reg = try getValueReg(ctx, x);
    const y_reg = try getValueReg(ctx, y);
    const dst = lower_mod.WritableReg.allocReg(.scalable_vector, ctx);

    return Inst{ .sve_eor = .{
        .dst = dst,
        .src1 = x_reg,
        .src2 = y_reg,
    } };
}

test "pinnedRegNum matches platform ABI" {
    const expected: u6 = switch (abi_mod.Platform.detect()) {
        .darwin => 18,
        .linux, .other => 28,
    };
    try std.testing.expectEqual(expected, pinnedRegNum());
}
