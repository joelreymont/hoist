//! ISLE constructor implementation for aarch64.
//! This module provides the glue between ISLE-generated lowering rules
//! and VCode emission. ISLE constructors call these functions to create
//! machine instructions that are emitted into the VCode buffer.

const std = @import("std");
const root = @import("../../root.zig");
const abi_mod = @import("abi.zig");

const Inst = root.aarch64_inst.Inst;
const Reg = root.aarch64_inst.Reg;
const PReg = root.aarch64_inst.PReg;
const WritableReg = root.aarch64_inst.WritableReg;
const OperandSize = root.aarch64_inst.OperandSize;
const FpuOperandSize = root.aarch64_inst.FpuOperandSize;
const CondCode = root.aarch64_inst.CondCode;
const BranchTarget = root.aarch64_inst.BranchTarget;
const ExtendOp = root.aarch64_inst.ExtendOp;
const ShiftOp = root.aarch64_inst.ShiftOp;
const Imm12 = root.aarch64_inst.Imm12;
const ImmLogic = root.aarch64_inst.ImmLogic;
const ImmShift = root.aarch64_inst.ImmShift;
const ir_externs = @import("../../dsl/isle/ir_externs.zig");

const lower_mod = root.lower;
const LowerCtx = lower_mod.LowerCtx;
const Value = lower_mod.Value;
const Block = lower_mod.Block;
const StackSlot = lower_mod.StackSlot;
const types = root.types;
const entities = root.entities;
const Type = types.Type;
const Offset32 = root.immediates.Offset32;
const condcodes = root.condcodes;
const IntCC = condcodes.IntCC;
const TrapCode = root.trapcode.TrapCode;
const isle_helpers = root.aarch64_isle_helpers;

/// Determine register class from IR type.
fn regClassForType(ty: Type) lower_mod.RegClass {
    if (ty.isDynamicVector()) return .scalable_vector;
    if (ty.isVector()) return .vector;
    return if (ty.isFloat()) .float else .int;
}

fn blkTarget(ctx: *IsleContext, blk: Block) !BranchTarget {
    return .{ .label = try ctx.lower_ctx.getBlockLabel(blk) };
}

fn vmctxReg(ctx: *IsleContext) !Reg {
    const sig = ctx.lower_ctx.func.sig;
    const vmctx_idx = sig.specialParamIndex(.vm_context) orelse return error.VmctxNotFound;

    const needs_sret = abi_mod.needsStructReturnPointer(sig.returns.items, null);
    const locs = try abi_mod.computeArgLocs(
        ctx.lower_ctx.allocator,
        sig.params.items,
        needs_sret,
        null,
    );
    defer ctx.lower_ctx.allocator.free(locs);

    return switch (locs[vmctx_idx]) {
        .reg => |preg| Reg.fromPReg(preg),
        .indirect_reg => |preg| Reg.fromPReg(preg),
        else => error.UnsupportedVmctxLocation,
    };
}

/// ISLE context for aarch64 lowering.
/// This wraps LowerCtx with backend-specific state needed by ISLE constructors.
pub const IsleContext = struct {
    /// Lowering context shared across backends.
    lower_ctx: *LowerCtx(Inst),

    pub fn init(ctx: *LowerCtx(Inst)) IsleContext {
        return .{ .lower_ctx = ctx };
    }

    /// Emit an instruction to VCode.
    pub fn emit(self: *IsleContext, inst: Inst) !void {
        try self.lower_ctx.emit(inst);
    }

    /// Get register for a value, allocating a vreg if needed.
    pub fn getValueReg(self: *IsleContext, value: Value, class: lower_mod.RegClass) !Reg {
        const vreg = try self.lower_ctx.getValueReg(value, class);
        return Reg.fromVReg(vreg);
    }

    /// Allocate a fresh output register.
    pub fn allocOutputReg(self: *IsleContext, class: lower_mod.RegClass) WritableReg {
        const vreg = self.lower_ctx.allocVReg(class);
        return WritableReg.fromVReg(vreg);
    }

    /// Allocate a fresh input register.
    pub fn allocInputReg(self: *IsleContext, class: lower_mod.RegClass) Reg {
        const vreg = self.lower_ctx.allocVReg(class);
        return Reg.fromVReg(vreg);
    }

    /// Convert IR type to aarch64 operand size.
    pub fn typeToSize(self: *IsleContext, ty: Type) OperandSize {
        _ = self;
        return if (ty.bits() <= 32) .size32 else .size64;
    }
};

const Ir = ir_externs.Externs(IsleContext);

pub const has_type_ext = Ir.has_type_ext;
pub const ty_vec_fits_in_register_ext = Ir.ty_vec_fits_in_register_ext;
pub const ty_32_or_64_ext = Ir.ty_32_or_64_ext;
pub const iadd_ext = Ir.iadd_ext;
pub const isub_ext = Ir.isub_ext;
pub const imul_ext = Ir.imul_ext;
pub const umul_hi_ext = Ir.umul_hi_ext;
pub const smul_hi_ext = Ir.smul_hi_ext;
pub const umulhi_ext = Ir.umulhi_ext;
pub const smulhi_ext = Ir.smulhi_ext;
pub const uadd_sat_ext = Ir.uadd_sat_ext;
pub const sadd_sat_ext = Ir.sadd_sat_ext;
pub const usub_sat_ext = Ir.usub_sat_ext;
pub const ssub_sat_ext = Ir.ssub_sat_ext;
pub const sqmul_round_sat_ext = Ir.sqmul_round_sat_ext;
pub const sdiv_ext = Ir.sdiv_ext;
pub const udiv_ext = Ir.udiv_ext;
pub const srem_ext = Ir.srem_ext;
pub const urem_ext = Ir.urem_ext;
pub const smin_ext = Ir.smin_ext;
pub const smax_ext = Ir.smax_ext;
pub const imin_ext = Ir.imin_ext;
pub const imax_ext = Ir.imax_ext;
pub const umin_ext = Ir.umin_ext;
pub const umax_ext = Ir.umax_ext;
pub const avg_round_ext = Ir.avg_round_ext;
pub const reduce_add_ext = Ir.reduce_add_ext;
pub const reduce_smin_ext = Ir.reduce_smin_ext;
pub const reduce_smax_ext = Ir.reduce_smax_ext;
pub const reduce_umin_ext = Ir.reduce_umin_ext;
pub const reduce_umax_ext = Ir.reduce_umax_ext;
pub const band_ext = Ir.band_ext;
pub const bor_ext = Ir.bor_ext;
pub const bxor_ext = Ir.bxor_ext;
pub const band_not_ext = Ir.band_not_ext;
pub const bor_not_ext = Ir.bor_not_ext;
pub const bxor_not_ext = Ir.bxor_not_ext;
pub const ishl_ext = Ir.ishl_ext;
pub const ushr_ext = Ir.ushr_ext;
pub const sshr_ext = Ir.sshr_ext;
pub const rotl_ext = Ir.rotl_ext;
pub const rotr_ext = Ir.rotr_ext;
pub const ineg_ext = Ir.ineg_ext;
pub const iabs_ext = Ir.iabs_ext;
pub const bnot_ext = Ir.bnot_ext;
pub const bitrev_ext = Ir.bitrev_ext;
pub const clz_ext = Ir.clz_ext;
pub const cls_ext = Ir.cls_ext;
pub const ctz_ext = Ir.ctz_ext;
pub const bswap_ext = Ir.bswap_ext;
pub const popcnt_ext = Ir.popcnt_ext;
pub const select_ext = Ir.select_ext;
pub const select_spectre_guard_ext = Ir.select_spectre_guard_ext;
pub const bitselect_ext = Ir.bitselect_ext;
pub const iadd_imm_ext = Ir.iadd_imm_ext;
pub const imul_imm_ext = Ir.imul_imm_ext;
pub const udiv_imm_ext = Ir.udiv_imm_ext;
pub const sdiv_imm_ext = Ir.sdiv_imm_ext;
pub const urem_imm_ext = Ir.urem_imm_ext;
pub const srem_imm_ext = Ir.srem_imm_ext;
pub const irsub_imm_ext = Ir.irsub_imm_ext;
pub const band_imm_ext = Ir.band_imm_ext;
pub const bor_imm_ext = Ir.bor_imm_ext;
pub const bxor_imm_ext = Ir.bxor_imm_ext;
pub const ishl_imm_ext = Ir.ishl_imm_ext;
pub const ushr_imm_ext = Ir.ushr_imm_ext;
pub const sshr_imm_ext = Ir.sshr_imm_ext;
pub const rotl_imm_ext = Ir.rotl_imm_ext;
pub const rotr_imm_ext = Ir.rotr_imm_ext;
pub const uadd_overflow_ext = Ir.uadd_overflow_ext;
pub const sadd_overflow_ext = Ir.sadd_overflow_ext;
pub const usub_overflow_ext = Ir.usub_overflow_ext;
pub const ssub_overflow_ext = Ir.ssub_overflow_ext;
pub const umul_overflow_ext = Ir.umul_overflow_ext;
pub const smul_overflow_ext = Ir.smul_overflow_ext;
pub const uadd_overflow_cin_ext = Ir.uadd_overflow_cin_ext;
pub const sadd_overflow_cin_ext = Ir.sadd_overflow_cin_ext;
pub const uadd_overflow_trap_ext = Ir.uadd_overflow_trap_ext;
pub const usub_overflow_trap_ext = Ir.usub_overflow_trap_ext;
pub const umul_overflow_trap_ext = Ir.umul_overflow_trap_ext;
pub const sadd_overflow_trap_ext = Ir.sadd_overflow_trap_ext;
pub const ssub_overflow_trap_ext = Ir.ssub_overflow_trap_ext;
pub const smul_overflow_trap_ext = Ir.smul_overflow_trap_ext;
pub const fadd_ext = Ir.fadd_ext;
pub const fsub_ext = Ir.fsub_ext;
pub const fmul_ext = Ir.fmul_ext;
pub const fdiv_ext = Ir.fdiv_ext;
pub const fmin_ext = Ir.fmin_ext;
pub const fmax_ext = Ir.fmax_ext;
pub const fma_ext = Ir.fma_ext;
pub const fneg_ext = Ir.fneg_ext;
pub const fabs_ext = Ir.fabs_ext;
pub const fcopysign_ext = Ir.fcopysign_ext;
pub const nearest_ext = Ir.nearest_ext;
pub const trunc_ext = Ir.trunc_ext;
pub const ceil_ext = Ir.ceil_ext;
pub const floor_ext = Ir.floor_ext;
pub const sqrt_ext = Ir.sqrt_ext;
pub const fsqrt_ext = Ir.fsqrt_ext;
pub const splat_ext = Ir.splat_ext;
pub const extractlane_ext = Ir.extractlane_ext;
pub const insertlane_ext = Ir.insertlane_ext;
pub const fdemote_ext = Ir.fdemote_ext;
pub const fpromote_ext = Ir.fpromote_ext;
pub const fvpromote_low_ext = Ir.fvpromote_low_ext;
pub const fvdemote_ext = Ir.fvdemote_ext;
pub const fcmp_ext = Ir.fcmp_ext;
pub const fcvt_from_sint_ext = Ir.fcvt_from_sint_ext;
pub const fcvt_from_uint_ext = Ir.fcvt_from_uint_ext;
pub const fcvt_to_sint_ext = Ir.fcvt_to_sint_ext;
pub const fcvt_to_uint_ext = Ir.fcvt_to_uint_ext;
pub const sextend_ext = Ir.sextend_ext;
pub const uextend_ext = Ir.uextend_ext;
pub const ireduce_ext = Ir.ireduce_ext;
pub const bitcast_ext = Ir.bitcast_ext;
pub const bmask_ext = Ir.bmask_ext;
pub const scalar_to_vector_ext = Ir.scalar_to_vector_ext;
pub const iadd_pairwise_ext = Ir.iadd_pairwise_ext;
pub const iconcat_ext = Ir.iconcat_ext;
pub const isplit_ext = Ir.isplit_ext;
pub const iconst_ext = Ir.iconst_ext;
pub const f32const_ext = Ir.f32const_ext;
pub const f64const_ext = Ir.f64const_ext;
pub const vconst_ext = Ir.vconst_ext;
pub const shuffle_ext = Ir.shuffle_ext;
pub const icmp_ext = Ir.icmp_ext;
pub const icmp_imm_ext = Ir.icmp_imm_ext;
pub const load_ext = Ir.load_ext;
pub const store_ext = Ir.store_ext;
pub const istore8_ext = Ir.istore8_ext;
pub const istore16_ext = Ir.istore16_ext;
pub const istore32_ext = Ir.istore32_ext;
pub const uload8x8_ext = Ir.uload8x8_ext;
pub const sload8x8_ext = Ir.sload8x8_ext;
pub const uload16x4_ext = Ir.uload16x4_ext;
pub const sload16x4_ext = Ir.sload16x4_ext;
pub const uload32x2_ext = Ir.uload32x2_ext;
pub const sload32x2_ext = Ir.sload32x2_ext;
pub const pre_inc_ext = Ir.pre_inc_ext;
pub const post_inc_ext = Ir.post_inc_ext;
pub const load_pair_ext = Ir.load_pair_ext;
pub const store_pair_ext = Ir.store_pair_ext;
pub const stack_addr_ext = Ir.stack_addr_ext;
pub const stack_load_ext = Ir.stack_load_ext;
pub const stack_store_ext = Ir.stack_store_ext;
pub const dynamic_stack_addr_ext = Ir.dynamic_stack_addr_ext;
pub const dynamic_stack_load_ext = Ir.dynamic_stack_load_ext;
pub const dynamic_stack_store_ext = Ir.dynamic_stack_store_ext;
pub const stack_switch_ext = Ir.stack_switch_ext;
pub const tls_value_ext = Ir.tls_value_ext;
pub const atomic_load_ext = Ir.atomic_load_ext;
pub const atomic_store_ext = Ir.atomic_store_ext;
pub const atomic_rmw_ext = Ir.atomic_rmw_ext;
pub const atomic_cas_ext = Ir.atomic_cas_ext;
pub const fence_ext = Ir.fence_ext;
pub const trap_ext = Ir.trap_ext;
pub const trapz_ext = Ir.trapz_ext;
pub const trapnz_ext = Ir.trapnz_ext;
pub const jump_ext = Ir.jump_ext;
pub const brif_ext = Ir.brif_ext;
pub const br_table_ext = Ir.br_table_ext;
pub const brz_ext = Ir.brz_ext;
pub const brnz_ext = Ir.brnz_ext;
pub const return_ext = Ir.return_ext;
pub const debugtrap_ext = Ir.debugtrap_ext;
pub const nop_ext = Ir.nop_ext;
pub const sequence_point_ext = Ir.sequence_point_ext;
pub const spectre_fence_ext = Ir.spectre_fence_ext;
pub const landingpad_ext = Ir.landingpad_ext;
pub const get_frame_pointer_ext = Ir.get_frame_pointer_ext;
pub const get_stack_pointer_ext = Ir.get_stack_pointer_ext;
pub const get_return_address_ext = Ir.get_return_address_ext;
pub const get_pinned_reg_ext = Ir.get_pinned_reg_ext;
pub const set_pinned_reg_ext = Ir.set_pinned_reg_ext;
pub const vall_true_ext = Ir.vall_true_ext;
pub const vany_true_ext = Ir.vany_true_ext;
pub const vhigh_bits_ext = Ir.vhigh_bits_ext;
pub const global_value_ext = Ir.global_value_ext;
pub const symbol_value_ext = Ir.symbol_value_ext;
pub const func_addr_ext = Ir.func_addr_ext;
pub const call_ext = Ir.call_ext;
pub const call_indirect_ext = Ir.call_indirect_ext;
pub const return_call_ext = Ir.return_call_ext;
pub const return_call_indirect_ext = Ir.return_call_indirect_ext;
pub const try_call_ext = Ir.try_call_ext;
pub const try_call_indirect_ext = Ir.try_call_indirect_ext;
pub const func_ref_data_ext = Ir.func_ref_data_ext;
pub const symbol_value_data_ext = Ir.symbol_value_data_ext;

pub fn aarch64_unimplemented(_: *IsleContext) !Inst {
    return error.Unimplemented;
}

// ============================================================================
// ISLE Constructors - Constants
// ============================================================================

pub fn aarch64_movz(
    ctx: *IsleContext,
    ty: Type,
    k: i64,
) !Inst {
    const size = ctx.typeToSize(ty);
    if (k < 0 or k > 0xffff) return error.ImmediateOutOfRange;

    const dst = ctx.allocOutputReg(.int);
    const inst = Inst{ .movz = .{
        .dst = dst,
        .imm = @intCast(k),
        .shift = 0,
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

pub fn aarch64_iconst(
    ctx: *IsleContext,
    ty: Type,
    k: i64,
) !Inst {
    const size = ctx.typeToSize(ty);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .mov_imm = .{
        .dst = dst,
        .imm = @bitCast(k),
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

// ============================================================================
// ISLE Constructors - Integer Arithmetic
// ============================================================================

/// Constructor: ADD register-register (ADD Xd, Xn, Xm).
/// Emits: dst = src1 + src2
pub fn aarch64_add_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .add_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: ADD with extended register (ADD Xd, Xn, Wm, extend).
/// Emits: dst = src1 + extend(src2)
pub fn aarch64_add_extended(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    extend: ExtendOp,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .add_extended = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .extend = extend,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: ADD with shifted register (ADD Xd, Xn, Xm, shift #amount).
/// Emits: dst = x + (y << shift_amt)
pub fn aarch64_add_shifted(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    shift_op: ShiftOp,
    shift_amt: u6,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .add_shifted = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .shift_op = shift_op,
        .shift_amt = shift_amt,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: ADD immediate (ADD Xd, Xn, #imm).
/// Emits: dst = src + imm
pub fn aarch64_add_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    imm: i64,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    if (imm < 0 or imm > 0xfff) return error.ImmediateOutOfRange;

    const inst = Inst{ .add_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = @intCast(imm),
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: SUB register-register (SUB Xd, Xn, Xm).
/// Emits: dst = src1 - src2
pub fn aarch64_sub_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .sub_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: SUB immediate (SUB Xd, Xn, #imm).
/// Emits: dst = src - imm
pub fn aarch64_sub_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    imm: i64,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    if (imm < 0 or imm > 0xfff) return error.ImmediateOutOfRange;

    const inst = Inst{ .sub_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = @intCast(imm),
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: SUB with shifted register (SUB Xd, Xn, Xm, shift #amount).
/// Emits: dst = x - (y << shift_amt)
pub fn aarch64_sub_shifted(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    shift_op: ShiftOp,
    shift_amt: u6,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .sub_shifted = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .shift_op = shift_op,
        .shift_amt = shift_amt,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: SUB with extended operand (SUB Xd, Xn, Xm, extend).
/// Emits: dst = src1 - extended(src2)
pub fn aarch64_sub_extended(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    extend: ExtendOp,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .sub_extended = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .extend = extend,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: MUL register-register (MUL Xd, Xn, Xm).
/// Emits: dst = src1 * src2
pub fn aarch64_mul_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .mul_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: MADD - multiply-add (MADD Xd, Xn, Xm, Xa).
/// Emits: dst = addend + (src1 * src2)
pub fn aarch64_madd(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    addend: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const reg_addend = try ctx.getValueReg(addend, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .madd = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .addend = reg_addend,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: MSUB - multiply-subtract (MSUB Xd, Xn, Xm, Xa).
/// Emits: dst = minuend - (src1 * src2)
pub fn aarch64_msub(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    minuend: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const reg_minuend = try ctx.getValueReg(minuend, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .msub = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .minuend = reg_minuend,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: SMULH - signed multiply high (SMULH Xd, Xn, Xm).
/// Emits: dst = (src1 * src2)[127:64] (signed)
pub fn aarch64_smulh(
    ctx: *IsleContext,
    x: Value,
    y: Value,
) !Inst {
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .smulh = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: UMULH - unsigned multiply high (UMULH Xd, Xn, Xm).
/// Emits: dst = (src1 * src2)[127:64] (unsigned)
pub fn aarch64_umulh(
    ctx: *IsleContext,
    x: Value,
    y: Value,
) !Inst {
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .umulh = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: SDIV - signed divide (SDIV Xd, Xn, Xm).
/// Emits: dst = src1 / src2 (signed)
pub fn aarch64_sdiv(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .sdiv = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: UDIV - unsigned divide (UDIV Xd, Xn, Xm).
/// Emits: dst = src1 / src2 (unsigned)
pub fn aarch64_udiv(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .udiv = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: SREM - signed remainder.
/// Emits: q = x / y; r = x - (q * y)
pub fn aarch64_srem(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);

    const quot = ctx.allocOutputReg(.int);
    const dst = ctx.allocOutputReg(.int);

    const div_inst = Inst{ .sdiv = .{
        .dst = quot,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(div_inst);

    const rem_inst = Inst{ .msub = .{
        .dst = dst,
        .src1 = quot.toReg(),
        .src2 = reg_y,
        .minuend = reg_x,
        .size = size,
    } };
    try ctx.emit(rem_inst);

    return rem_inst;
}

/// Constructor: UREM - unsigned remainder.
/// Emits: q = x / y; r = x - (q * y)
pub fn aarch64_urem(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);

    const quot = ctx.allocOutputReg(.int);
    const dst = ctx.allocOutputReg(.int);

    const div_inst = Inst{ .udiv = .{
        .dst = quot,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(div_inst);

    const rem_inst = Inst{ .msub = .{
        .dst = dst,
        .src1 = quot.toReg(),
        .src2 = reg_y,
        .minuend = reg_x,
        .size = size,
    } };
    try ctx.emit(rem_inst);

    return rem_inst;
}

// ============================================================================
// ISLE Constructors - Bitwise Operations
// ============================================================================

/// Constructor: AND register-register (AND Xd, Xn, Xm).
/// Emits: dst = src1 & src2
pub fn aarch64_and_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .and_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: AND with logical immediate (AND Xd, Xn, #imm).
/// Emits: dst = src & imm
pub fn aarch64_and_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    imm: ImmLogic,
) !Inst {
    _ = ty;
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .and_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = imm,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: ORR register-register (ORR Xd, Xn, Xm).
/// Emits: dst = src1 | src2
pub fn aarch64_orr_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .orr_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: ORR with logical immediate (ORR Xd, Xn, #imm).
/// Emits: dst = src | imm
pub fn aarch64_orr_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    imm: ImmLogic,
) !Inst {
    _ = ty;
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .orr_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = imm,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: EOR register-register (EOR Xd, Xn, Xm).
/// Emits: dst = src1 ^ src2
pub fn aarch64_eor_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .eor_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: EOR with logical immediate (EOR Xd, Xn, #imm).
/// Emits: dst = src ^ imm
pub fn aarch64_eor_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    imm: ImmLogic,
) !Inst {
    _ = ty;
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .eor_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = imm,
    } };
    try ctx.emit(inst);

    return inst;
}

/// Constructor: AND with shifted register (AND Xd, Xn, Xm, shift #amt).
/// Emits: dst = src1 & (src2 << shift_amt)
pub fn aarch64_and_shifted(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    shift_op: ShiftOp,
    shift_amt: u6,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .and_shifted = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .shift_op = shift_op,
        .shift_amt = shift_amt,
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: ORR with shifted register (ORR Xd, Xn, Xm, shift #amt).
/// Emits: dst = src1 | (src2 << shift_amt)
pub fn aarch64_orr_shifted(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    shift_op: ShiftOp,
    shift_amt: u6,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .orr_shifted = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .shift_op = shift_op,
        .shift_amt = shift_amt,
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: EOR with shifted register (EOR Xd, Xn, Xm, shift #amt).
/// Emits: dst = src1 ^ (src2 << shift_amt)
pub fn aarch64_eor_shifted(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    shift_op: ShiftOp,
    shift_amt: u6,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .eor_shifted = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .shift_op = shift_op,
        .shift_amt = shift_amt,
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

// ============================================================================
// ISLE Constructors - Shift Operations
// ============================================================================

/// Constructor: LSL register-register (LSL Xd, Xn, Xm).
/// Emits: dst = src1 << src2
pub fn aarch64_lsl_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .lsl_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: LSL immediate (LSL Xd, Xn, #imm).
/// Emits: dst = src << imm
pub fn aarch64_lsl_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    shift: u8,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .lsl_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = shift,
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: LSR register-register (LSR Xd, Xn, Xm).
/// Emits: dst = src1 >> src2 (logical)
pub fn aarch64_lsr_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .lsr_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: LSR immediate (LSR Xd, Xn, #imm).
/// Emits: dst = src >> imm (logical)
pub fn aarch64_lsr_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    shift: u8,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .lsr_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = shift,
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: ASR register-register (ASR Xd, Xn, Xm).
/// Emits: dst = src1 >> src2 (arithmetic)
pub fn aarch64_asr_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .asr_rr = .{
        .dst = dst,
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: ASR immediate (ASR Xd, Xn, #imm).
/// Emits: dst = src >> imm (arithmetic)
pub fn aarch64_asr_imm(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    shift: u8,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .asr_imm = .{
        .dst = dst,
        .src = reg_x,
        .imm = shift,
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

// ============================================================================
// ISLE Constructors - Move Operations
// ============================================================================

/// Constructor: MOV register (MOV Xd, Xn).
/// Emits: dst = src
pub fn aarch64_mov_rr(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .mov_rr = .{
        .dst = dst,
        .src = reg_x,
        .size = size,
    } });

    return dst;
}

/// Constructor: MOV immediate (MOV Xd, #imm).
/// Emits: dst = imm
pub fn aarch64_mov_imm(
    ctx: *IsleContext,
    ty: Type,
    imm: u64,
) !WritableReg {
    const size = ctx.typeToSize(ty);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(.{ .mov_imm = .{
        .dst = dst,
        .imm = imm,
        .size = size,
    } });

    return dst;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn mkFunc(allocator: std.mem.Allocator) !lower_mod.Function {
    const sig = root.signature.Signature.init(allocator, .system_v);
    return lower_mod.Function.init(allocator, "test", sig);
}

test "IsleContext creation" {
    var func = try mkFunc(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    const ctx = IsleContext.init(&lower_ctx);
    try testing.expect(@intFromPtr(ctx.lower_ctx) != 0);
}

test "aarch64_global_value vmctx uses abi reg" {
    var sig = root.signature.Signature.init(testing.allocator, .system_v);
    try sig.params.append(
        testing.allocator,
        root.signature.AbiParam.special(Type.I64, .vm_context),
    );

    var func = try lower_mod.Function.init(testing.allocator, "vmctx", sig);
    defer func.deinit();

    const gv = try func.global_values.push(.{ .vmctx = {} });

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);
    _ = try aarch64_global_value(&ctx, gv);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.mov_rr, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    const mov = vcode.insns.items[0].mov_rr;
    const expected = Reg.fromPReg(PReg.new(.int, 0));
    try testing.expectEqual(expected.bits, mov.src.bits);
}

test "aarch64_add_rr constructor" {
    var func = try mkFunc(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    // Start a block to allow emission
    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);
    const v2 = Value.new(1);

    const inst = try aarch64_add_rr(&ctx, Type.I64, v1, v2);

    // Verify instruction was emitted
    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.add_rr, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(OperandSize.size64, vcode.insns.items[0].add_rr.size);

    try testing.expectEqual(Inst.add_rr, @as(std.meta.Tag(Inst), inst));
    _ = inst.add_rr.dst.toReg();
}

test "aarch64_mul_rr constructor" {
    var func = try mkFunc(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);
    const v2 = Value.new(1);

    const inst = try aarch64_mul_rr(&ctx, Type.I32, v1, v2);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.mul_rr, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(OperandSize.size32, vcode.insns.items[0].mul_rr.size);

    try testing.expectEqual(Inst.mul_rr, @as(std.meta.Tag(Inst), inst));
    _ = inst.mul_rr.dst.toReg();
}

test "aarch64_madd constructor - multiply-add fusion" {
    var func = try mkFunc(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);
    const v2 = Value.new(1);
    const v3 = Value.new(2);

    // MADD: v3 + (v1 * v2)
    const inst = try aarch64_madd(&ctx, Type.I64, v1, v2, v3);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.madd, @as(std.meta.Tag(Inst), vcode.insns.items[0]));

    try testing.expectEqual(Inst.madd, @as(std.meta.Tag(Inst), inst));
    _ = inst.madd.dst.toReg();
}

test "aarch64_and_imm constructor with logical immediate" {
    var func = try mkFunc(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);

    // AND with 0xFF (valid logical immediate)
    const imm = ImmLogic.maybeFromU64(0xFF, .size64) orelse return error.InvalidImmediate;
    const inst = try aarch64_and_imm(&ctx, Type.I64, v1, imm);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.and_imm, @as(std.meta.Tag(Inst), vcode.insns.items[0]));

    try testing.expectEqual(Inst.and_imm, @as(std.meta.Tag(Inst), inst));
}

test "aarch64_lsl_imm constructor" {
    var func = try mkFunc(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);

    const dst = try aarch64_lsl_imm(&ctx, Type.I64, v1, 8);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.lsl_imm, @as(std.meta.Tag(Inst), vcode.insns.items[0]));
    try testing.expectEqual(@as(u8, 8), vcode.insns.items[0].lsl_imm.imm);
    _ = dst;
}

test "aarch64_smulh constructor for high multiply" {
    var func = try mkFunc(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    _ = try lower_ctx.startBlock(lower_mod.Block.new(0));

    var ctx = IsleContext.init(&lower_ctx);

    const v1 = Value.new(0);
    const v2 = Value.new(1);

    const inst = try aarch64_smulh(&ctx, v1, v2);

    try testing.expectEqual(@as(usize, 1), vcode.insns.items.len);
    try testing.expectEqual(Inst.smulh, @as(std.meta.Tag(Inst), vcode.insns.items[0]));

    try testing.expectEqual(Inst.smulh, @as(std.meta.Tag(Inst), inst));
    _ = inst.smulh.dst.toReg();
}

test "typeToSize maps types correctly" {
    var func = try mkFunc(testing.allocator);
    defer func.deinit();

    var vcode = root.vcode.VCode(Inst).init(testing.allocator);
    defer vcode.deinit();

    var lower_ctx = LowerCtx(Inst).init(testing.allocator, &func, &vcode);
    defer lower_ctx.deinit();

    var ctx = IsleContext.init(&lower_ctx);

    try testing.expectEqual(OperandSize.size32, ctx.typeToSize(Type.I8));
    try testing.expectEqual(OperandSize.size32, ctx.typeToSize(Type.I16));
    try testing.expectEqual(OperandSize.size32, ctx.typeToSize(Type.I32));
    try testing.expectEqual(OperandSize.size64, ctx.typeToSize(Type.I64));
}

/// Convert IntCC to AArch64 CondCode.
fn intccToCondCode(cc: IntCC) CondCode {
    return switch (cc) {
        .eq => .eq,
        .ne => .ne,
        .slt => .lt,
        .sge => .ge,
        .sgt => .gt,
        .sle => .le,
        .ult => .cc,
        .uge => .cs,
        .ugt => .hi,
        .ule => .ls,
    };
}

/// Constructor: B - Unconditional branch.
pub fn aarch64_b(
    ctx: *IsleContext,
    target: Block,
) !Inst {
    const inst = Inst{ .b = .{ .target = try blkTarget(ctx, target) } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: branch on a boolean value (non-zero is taken).
pub fn aarch64_b_cond(
    ctx: *IsleContext,
    cond: Value,
    target: Block,
) !Inst {
    return aarch64_cbnz(ctx, cond, target);
}

/// Constructor: CMP+branch fusion (CMP x, y; B.cond target).
/// Emits CMP instruction followed by conditional branch.
/// Avoids materializing comparison result in a register.
pub fn aarch64_cmp_and_branch(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    y: Value,
    cc: IntCC,
    target: Block,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const reg_y = try ctx.getValueReg(y, .int);
    const cond = intccToCondCode(cc);

    // Emit CMP instruction
    try ctx.emit(.{ .cmp_rr = .{
        .src1 = reg_x,
        .src2 = reg_y,
        .size = size,
    } });

    const inst = Inst{ .b_cond = .{
        .cond = cond,
        .target = try blkTarget(ctx, target),
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: CMP immediate + branch fusion.
pub fn aarch64_cmp_imm_and_branch(
    ctx: *IsleContext,
    ty: Type,
    x: Value,
    imm: i64,
    cc: IntCC,
    target: Block,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_x = try ctx.getValueReg(x, .int);
    const cond = intccToCondCode(cc);

    if (imm >= 0) {
        const imm_u: u64 = @intCast(imm);
        if (Imm12.maybeFromU64(imm_u)) |imm12| {
            try ctx.emit(.{ .cmp_imm = .{
                .src = reg_x,
                .imm = imm12,
                .size = size,
            } });
        } else {
            const tmp = ctx.allocOutputReg(.int);
            try ctx.emit(.{ .mov_imm = .{
                .dst = tmp,
                .imm = imm_u,
                .size = size,
            } });
            try ctx.emit(.{ .cmp_rr = .{
                .src1 = reg_x,
                .src2 = tmp.toReg(),
                .size = size,
            } });
        }
    } else {
        const tmp = ctx.allocOutputReg(.int);
        try ctx.emit(.{ .mov_imm = .{
            .dst = tmp,
            .imm = @bitCast(imm),
            .size = size,
        } });
        try ctx.emit(.{ .cmp_rr = .{
            .src1 = reg_x,
            .src2 = tmp.toReg(),
            .size = size,
        } });
    }

    const inst = Inst{ .b_cond = .{
        .cond = cond,
        .target = try blkTarget(ctx, target),
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: CBZ - Compare and branch if zero.
/// Emits a CBZ instruction that branches to target if x == 0.
pub fn aarch64_cbz(
    ctx: *IsleContext,
    x: Value,
    target: Block,
) !Inst {
    const ty = try ctx.lower_ctx.getValueType(x);
    const size = ctx.typeToSize(ty);
    const reg = try ctx.getValueReg(x, .int);

    const inst = Inst{ .cbz = .{
        .reg = reg,
        .target = try blkTarget(ctx, target),
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: CBNZ - Compare and branch if non-zero.
/// Emits a CBNZ instruction that branches to target if x != 0.
pub fn aarch64_cbnz(
    ctx: *IsleContext,
    x: Value,
    target: Block,
) !Inst {
    const ty = try ctx.lower_ctx.getValueType(x);
    const size = ctx.typeToSize(ty);
    const reg = try ctx.getValueReg(x, .int);

    const inst = Inst{ .cbnz = .{
        .reg = reg,
        .target = try blkTarget(ctx, target),
        .size = size,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: TBZ - Test bit and branch if zero.
/// Emits a TBZ instruction that branches to target if bit N of x is zero.
pub fn aarch64_tbz(
    ctx: *IsleContext,
    x: Value,
    bit: u8,
    target: Block,
) !Inst {
    const reg = try ctx.getValueReg(x, .int);

    const inst = Inst{ .tbz = .{
        .reg = reg,
        .bit = bit,
        .target = try blkTarget(ctx, target),
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: TBNZ - Test bit and branch if non-zero.
/// Emits a TBNZ instruction that branches to target if bit N of x is non-zero.
pub fn aarch64_tbnz(
    ctx: *IsleContext,
    x: Value,
    bit: u8,
    target: Block,
) !Inst {
    const reg = try ctx.getValueReg(x, .int);

    const inst = Inst{ .tbnz = .{
        .reg = reg,
        .bit = bit,
        .target = try blkTarget(ctx, target),
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: RET - Return from function.
pub fn aarch64_ret(ctx: *IsleContext) !Inst {
    const inst = Inst{ .ret = {} };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: stack_addr - compute address of stack slot.
/// Emits an address materialization into a fresh GPR.
pub fn aarch64_stack_addr(
    ctx: *IsleContext,
    stack_slot: StackSlot,
    offset: Offset32,
) !Inst {
    const slot_off = ctx.lower_ctx.getStackSlotOffset(stack_slot);
    const total_off: i64 = @as(i64, slot_off) + @as(i64, offset.bits());

    const dst = ctx.allocOutputReg(.int);
    const sp = Reg.gpr(31);

    if (total_off >= 0 and total_off <= 4095) {
        const inst = Inst{ .add_imm = .{
            .dst = dst,
            .src = sp,
            .imm = @intCast(total_off),
            .size = .size64,
        } };
        try ctx.emit(inst);
        return inst;
    }

    const off_reg = ctx.allocOutputReg(.int);
    try ctx.emit(Inst{ .mov_imm = .{
        .dst = off_reg,
        .imm = @bitCast(total_off),
        .size = .size64,
    } });

    const inst = Inst{ .add_rr = .{
        .dst = dst,
        .src1 = sp,
        .src2 = off_reg.toReg(),
        .size = .size64,
    } };
    try ctx.emit(inst);
    return inst;
}

fn stackAddrReg(addr_inst: Inst) !Reg {
    const dst = switch (addr_inst) {
        .add_imm => |i| i.dst,
        .add_rr => |i| i.dst,
        else => return error.UnexpectedStackAddrInst,
    };
    return dst.toReg();
}

/// Constructor: stack_load - load from stack slot.
pub fn aarch64_stack_load(
    ctx: *IsleContext,
    ty: Type,
    stack_slot: StackSlot,
    offset: Offset32,
) !Inst {
    const addr_inst = try aarch64_stack_addr(ctx, stack_slot, offset);
    const base = try stackAddrReg(addr_inst);

    const dst_class = regClassForType(ty);
    const dst = ctx.allocOutputReg(dst_class);

    const bits = ty.bits();
    const inst = if (ty.isInt()) blk: {
        if (bits == 64) break :blk Inst{ .ldr = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .size64,
        } };
        if (bits == 32) break :blk Inst{ .ldr = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .size32,
        } };
        if (bits == 16) break :blk Inst{ .ldrh = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .size32,
        } };
        if (bits == 8) break :blk Inst{ .ldrb = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = .size32,
        } };
        return error.UnsupportedIntegerSize;
    } else if (ty.isFloat()) blk: {
        const size: FpuOperandSize = switch (bits) {
            32 => .size32,
            64 => .size64,
            else => return error.UnsupportedFloatSize,
        };
        break :blk Inst{ .vldr = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = size,
        } };
    } else if (ty.isVector()) blk: {
        const size: FpuOperandSize = switch (bits) {
            1...32 => .size32,
            33...64 => .size64,
            128 => .size128,
            else => return error.UnsupportedVectorSize,
        };
        break :blk Inst{ .vldr = .{
            .dst = dst,
            .base = base,
            .offset = 0,
            .size = size,
        } };
    } else if (ty.isDynamicVector()) {
        return error.Unimplemented;
    } else {
        return error.UnsupportedType;
    };

    try ctx.emit(inst);
    return inst;
}

/// Constructor: stack_store - store to stack slot.
pub fn aarch64_stack_store(
    ctx: *IsleContext,
    ty: Type,
    value: Value,
    stack_slot: StackSlot,
    offset: Offset32,
) !Inst {
    const addr_inst = try aarch64_stack_addr(ctx, stack_slot, offset);
    const base = try stackAddrReg(addr_inst);

    const val_reg = try ctx.getValueReg(value, regClassForType(ty));
    const bits = ty.bits();

    const inst = if (ty.isInt()) blk: {
        if (bits == 64) break :blk Inst{ .str = .{
            .src = val_reg,
            .base = base,
            .offset = 0,
            .size = .size64,
        } };
        if (bits == 32) break :blk Inst{ .str = .{
            .src = val_reg,
            .base = base,
            .offset = 0,
            .size = .size32,
        } };
        if (bits == 16) break :blk Inst{ .strh = .{
            .src = val_reg,
            .base = base,
            .offset = 0,
        } };
        if (bits == 8) break :blk Inst{ .strb = .{
            .src = val_reg,
            .base = base,
            .offset = 0,
        } };
        return error.UnsupportedIntegerSize;
    } else if (ty.isFloat()) blk: {
        const size: FpuOperandSize = switch (bits) {
            32 => .size32,
            64 => .size64,
            else => return error.UnsupportedFloatSize,
        };
        break :blk Inst{ .vstr = .{
            .src = val_reg,
            .base = base,
            .offset = 0,
            .size = size,
        } };
    } else if (ty.isVector()) blk: {
        const size: FpuOperandSize = switch (bits) {
            1...32 => .size32,
            33...64 => .size64,
            128 => .size128,
            else => return error.UnsupportedVectorSize,
        };
        break :blk Inst{ .vstr = .{
            .src = val_reg,
            .base = base,
            .offset = 0,
            .size = size,
        } };
    } else if (ty.isDynamicVector()) {
        return error.Unimplemented;
    } else {
        return error.UnsupportedType;
    };

    try ctx.emit(inst);
    return inst;
}

/// Constructor: global_value - load address of global value.
/// Emits ADRP+ADD sequence for PC-relative global addressing.
fn gvInto(
    ctx: *IsleContext,
    gv: entities.GlobalValue,
    dst: WritableReg,
) !Inst {
    const gv_data = &ctx.lower_ctx.func.global_values.elems.items[gv.toIndex()];

    return switch (gv_data.*) {
        .vmctx => blk: {
            const src_reg = try vmctxReg(ctx);
            const inst = Inst{ .mov_rr = .{
                .dst = dst,
                .src = src_reg,
                .size = .size64,
            } };
            try ctx.emit(inst);
            break :blk inst;
        },
        .symbol => |sym_data| blk: {
            const symbol_name = try root.extfunc.symName(ctx.lower_ctx.allocator, sym_data.name);

            const adrp = Inst{ .adrp_symbol = .{
                .dst = dst,
                .symbol = symbol_name,
            } };
            try ctx.emit(adrp);

            const inst = Inst{ .add_symbol_lo12 = .{
                .dst = dst,
                .src = dst.toReg(),
                .symbol = symbol_name,
            } };
            try ctx.emit(inst);
            break :blk inst;
        },
        .iadd_imm => |add_data| blk: {
            _ = try gvInto(ctx, add_data.base, dst);
            const offset: i64 = add_data.offset.value;

            if (offset >= 0 and offset <= 0xfff) {
                const inst = Inst{ .add_imm = .{
                    .dst = dst,
                    .src = dst.toReg(),
                    .imm = @intCast(offset),
                    .size = .size64,
                } };
                try ctx.emit(inst);
                break :blk inst;
            }
            if (offset < 0 and offset >= -0xfff) {
                const inst = Inst{ .sub_imm = .{
                    .dst = dst,
                    .src = dst.toReg(),
                    .imm = @intCast(-offset),
                    .size = .size64,
                } };
                try ctx.emit(inst);
                break :blk inst;
            }

            const off_reg = ctx.allocInputReg(.int);
            try ctx.emit(Inst{ .mov_imm = .{
                .dst = WritableReg.fromReg(off_reg),
                .imm = @bitCast(offset),
                .size = .size64,
            } });

            const inst = Inst{ .add_rr = .{
                .dst = dst,
                .src1 = dst.toReg(),
                .src2 = off_reg,
                .size = .size64,
            } };
            try ctx.emit(inst);
            break :blk inst;
        },
        .load => |load_data| blk: {
            _ = try gvInto(ctx, load_data.base, dst);
            const offset_i32: i32 = load_data.offset.value;

            if (offset_i32 >= std.math.minInt(i16) and offset_i32 <= std.math.maxInt(i16)) {
                const inst = Inst{ .ldr = .{
                    .dst = dst,
                    .base = dst.toReg(),
                    .offset = @intCast(offset_i32),
                    .size = .size64,
                } };
                try ctx.emit(inst);
                break :blk inst;
            }

            const off_reg = ctx.allocInputReg(.int);
            try ctx.emit(Inst{ .mov_imm = .{
                .dst = WritableReg.fromReg(off_reg),
                .imm = @bitCast(@as(i64, offset_i32)),
                .size = .size64,
            } });

            try ctx.emit(Inst{ .add_rr = .{
                .dst = dst,
                .src1 = dst.toReg(),
                .src2 = off_reg,
                .size = .size64,
            } });

            const inst = Inst{ .ldr = .{
                .dst = dst,
                .base = dst.toReg(),
                .offset = 0,
                .size = .size64,
            } };
            try ctx.emit(inst);
            break :blk inst;
        },
        .dyn_scale_target_const => |_| error.Unimplemented,
    };
}

pub fn aarch64_global_value(
    ctx: *IsleContext,
    gv: entities.GlobalValue,
) !Inst {
    const dst = ctx.allocOutputReg(.int);
    return gvInto(ctx, gv, dst);
}

/// Constructor: br_table - branch table (jump table dispatch).
/// Emits bounds check + jump table lookup + indirect branch.
pub fn aarch64_br_table(
    ctx: *IsleContext,
    index: Value,
    jt: entities.JumpTable,
    default_target: Block,
) !Inst {
    // Get the jump table from function data
    const jt_data = &ctx.lower_ctx.func.jump_tables.elems.items[jt.toIndex()];
    const table_size: u32 = @intCast(jt_data.len());

    const default_label: BranchTarget = .{ .label = try ctx.lower_ctx.getBlockLabel(default_target) };

    // Degenerate table: always branch to default.
    if (table_size == 0) {
        const inst = Inst{ .b = .{ .target = default_label } };
        try ctx.emit(inst);
        return inst;
    }

    // Get index register (should be i32 or i64)
    const index_reg = try ctx.getValueReg(index, .int);
    const index_ty = try ctx.lower_ctx.getValueType(index);
    const index_size: OperandSize = if (index_ty.bits() <= 32) .size32 else .size64;
    const table_size_u64: u64 = @intCast(table_size);

    // Allocate temporary registers
    const table_base = ctx.allocOutputReg(.int);
    const target_reg = ctx.allocOutputReg(.int);

    // 1. Bounds check: if (index >= table_size) goto default
    if (Imm12.maybeFromU64(table_size_u64)) |imm| {
        try ctx.emit(Inst{ .cmp_imm = .{
            .src = index_reg,
            .imm = imm,
            .size = index_size,
        } });
    } else {
        const size_reg = ctx.allocOutputReg(.int);
        try ctx.emit(Inst{ .mov_imm = .{
            .dst = size_reg,
            .imm = table_size_u64,
            .size = index_size,
        } });
        try ctx.emit(Inst{ .cmp_rr = .{
            .src1 = index_reg,
            .src2 = size_reg.toReg(),
            .size = index_size,
        } });
    }

    // Branch to default if index >= size (unsigned HS = higher or same)
    try ctx.emit(Inst{
        .b_cond = .{
            .cond = .cs, // Carry set (unsigned >=)
            .target = default_label,
        },
    });

    // 3. Build target list for jt_sequence instruction
    // Extract blocks from jump table
    const targets = try ctx.lower_ctx.vcode.allocator.alloc(entities.Block, jt_data.len());
    for (jt_data.asSlice(), 0..) |block_call, i| {
        targets[i] = try block_call.block(&ctx.lower_ctx.func.dfg.value_lists);
    }

    // 4. Emit jt_sequence: Load table address, load offset, compute target, branch
    const inst = Inst{
        .jt_sequence = .{
            // Element index (hardware scales by 4 for 32-bit entries).
            .index = index_reg,
            .targets = targets,
            .table_base = table_base,
            .target = target_reg,
        },
    };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: uadd_overflow_cin - unsigned add with carry-in and overflow.
/// Returns ValueRegs.pair(result, overflow_out).
pub fn aarch64_uadd_overflow_cin(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    cin: Value,
) !lower_mod.ValueRegs {
    isle_helpers.recordRule("aarch64_uadd_overflow_cin");
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const cin_reg = try ctx.getValueReg(cin, .int);
    const is_64 = ty.bits() == 64;

    const size: OperandSize = if (is_64) .size64 else .size32;

    // Set carry flag from carry-in value: CMP cin, #0 (sets carry if cin != 0)
    // Actually, we need: SUBS XZR, cin, #1 (sets carry if cin >= 1, i.e., cin == 1)
    try ctx.emit(Inst{
        .subs_imm = .{
            .dst = WritableReg.fromReg(Reg.gpr(31)), // XZR (discard result)
            .src = cin_reg,
            .imm = .{ .bits = 1, .shift12 = false },
            .size = size,
        },
    });

    // ADCS: Add with carry and set flags
    const dst = ctx.allocOutputReg(.int);
    try ctx.emit(Inst{ .adcs = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = size,
    } });

    // CSET: Extract carry flag as overflow
    const overflow_reg = ctx.allocOutputReg(.int);
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .cs, // Carry set (unsigned overflow)
            .size = size,
        },
    });

    return lower_mod.ValueRegs.pair(dst.toReg(), overflow_reg.toReg());
}

/// Constructor: sadd_overflow_cin - signed add with carry-in and overflow.
/// Returns ValueRegs.pair(result, overflow_out).
pub fn aarch64_sadd_overflow_cin(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    cin: Value,
) !lower_mod.ValueRegs {
    isle_helpers.recordRule("aarch64_sadd_overflow_cin");
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const cin_reg = try ctx.getValueReg(cin, .int);
    const is_64 = ty.bits() == 64;

    const size: OperandSize = if (is_64) .size64 else .size32;

    // Set carry flag from carry-in value: SUBS XZR, cin, #1
    try ctx.emit(Inst{
        .subs_imm = .{
            .dst = WritableReg.fromReg(Reg.gpr(31)), // XZR
            .src = cin_reg,
            .imm = .{ .bits = 1, .shift12 = false },
            .size = size,
        },
    });

    // ADCS: Add with carry and set flags
    const dst = ctx.allocOutputReg(.int);
    try ctx.emit(Inst{ .adcs = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = size,
    } });

    // CSET: Extract overflow flag (V flag for signed overflow)
    const overflow_reg = ctx.allocOutputReg(.int);
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .vs, // VS = overflow set (signed overflow)
            .size = size,
        },
    });

    return lower_mod.ValueRegs.pair(dst.toReg(), overflow_reg.toReg());
}

/// Constructor: usub_overflow_cin - unsigned subtract with carry-in and overflow detection.
/// Returns (result, overflow) where overflow is 1 if borrow occurred.
/// Uses SBCS for subtract with carry, CSET to extract borrow flag.
pub fn aarch64_usub_overflow_cin(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    cin: Value,
) !lower_mod.ValueRegs {
    isle_helpers.recordRule("aarch64_usub_overflow_cin");
    const size = ctx.typeToSize(ty);
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const cin_reg = try ctx.getValueReg(cin, .int);
    const dst = ctx.allocOutputReg(.int);
    const overflow_reg = ctx.allocOutputReg(.int);

    // Set carry flag from carry-in (borrow): SUBS XZR, cin, #1
    // If cin=0 (borrow in), carry flag=0 (borrow propagates)
    // If cin=1 (no borrow), carry flag=1 (no borrow)
    try ctx.emit(Inst{
        .subs_imm = .{
            .dst = WritableReg.fromReg(Reg.gpr(31)), // XZR (discard result)
            .src = cin_reg,
            .imm = .{ .bits = 1, .shift12 = false },
            .size = size,
        },
    });

    // SBCS: Subtract with carry - dst = a - b - !carry
    try ctx.emit(Inst{ .sbcs = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = size,
    } });

    // CSET: Extract borrow flag (LO = borrow occurred)
    try ctx.emit(Inst{
        .cset = .{
            .dst = overflow_reg,
            .cond = .cc, // Carry clear (borrow/unsigned underflow)
            .size = size,
        },
    });

    return lower_mod.ValueRegs.pair(dst.toReg(), overflow_reg.toReg());
}

/// Constructor: uadd_overflow_trap - unsigned add with overflow trap.
/// Emits ADDS to set carry flag, B.CC to skip trap, UDF to trap on overflow.
pub fn aarch64_uadd_overflow_trap(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    code: TrapCode,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_a = try ctx.getValueReg(a, .int);
    const reg_b = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    // ADDS dst, a, b (sets carry flag on unsigned overflow)
    const inst = Inst{ .adds_rr = .{
        .dst = dst,
        .src1 = reg_a,
        .src2 = reg_b,
        .size = size,
    } };
    try ctx.emit(inst);

    // Skip trap if no carry (no overflow); skip next instruction (UDF).
    try ctx.emit(.{ .b_cond = .{
        .cond = .cc,
        .target = .{ .offset = 8 },
    } });

    // UDF (trap on overflow)
    try ctx.emit(.{ .udf = .{
        .imm = @intCast(code.toRaw()),
    } });
    return inst;
}

/// Constructor: usub_overflow_trap - unsigned subtract with overflow trap.
/// Emits SUBS to set carry flag, B.CS to skip trap, UDF to trap on borrow.
pub fn aarch64_usub_overflow_trap(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    code: TrapCode,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_a = try ctx.getValueReg(a, .int);
    const reg_b = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    // SUBS dst, a, b (sets carry flag on unsigned underflow/borrow)
    const inst = Inst{ .subs_rr = .{
        .dst = dst,
        .src1 = reg_a,
        .src2 = reg_b,
        .size = size,
    } };
    try ctx.emit(inst);

    // Skip trap if carry set (no borrow); skip next instruction (UDF).
    try ctx.emit(.{ .b_cond = .{
        .cond = .cs,
        .target = .{ .offset = 8 },
    } });

    // UDF (trap on underflow)
    try ctx.emit(.{ .udf = .{
        .imm = @intCast(code.toRaw()),
    } });
    return inst;
}

/// Constructor: umul_overflow_trap - unsigned multiply with overflow trap.
/// Uses UMULH to get high bits, checks if non-zero for overflow.
pub fn aarch64_umul_overflow_trap(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    code: TrapCode,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_a = try ctx.getValueReg(a, .int);
    const reg_b = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);
    const zero = Imm12.maybeFromU64(0).?;

    switch (size) {
        .size64 => {
            const mul = Inst{ .mul_rr = .{
                .dst = dst,
                .src1 = reg_a,
                .src2 = reg_b,
                .size = .size64,
            } };
            try ctx.emit(mul);

            const high = ctx.allocOutputReg(.int);
            try ctx.emit(.{ .umulh = .{
                .dst = high,
                .src1 = reg_a,
                .src2 = reg_b,
            } });

            try ctx.emit(.{ .cmp_imm = .{
                .src = high.toReg(),
                .imm = zero,
                .size = .size64,
            } });

            // Skip trap if high == 0; skip next instruction (UDF).
            try ctx.emit(.{ .b_cond = .{
                .cond = .eq,
                .target = .{ .offset = 8 },
            } });

            try ctx.emit(.{ .udf = .{ .imm = @intCast(code.toRaw()) } });
            return mul;
        },
        .size32 => {
            const prod = ctx.allocOutputReg(.int);
            try ctx.emit(.{ .umull = .{
                .dst = prod,
                .src1 = reg_a,
                .src2 = reg_b,
            } });

            const high = ctx.allocOutputReg(.int);
            try ctx.emit(.{ .lsr_imm = .{
                .dst = high,
                .src = prod.toReg(),
                .imm = 32,
                .size = .size64,
            } });

            try ctx.emit(.{ .cmp_imm = .{
                .src = high.toReg(),
                .imm = zero,
                .size = .size64,
            } });

            // Skip trap if high == 0; skip next instruction (UDF).
            try ctx.emit(.{ .b_cond = .{
                .cond = .eq,
                .target = .{ .offset = 8 },
            } });

            try ctx.emit(.{ .udf = .{ .imm = @intCast(code.toRaw()) } });

            const mov = Inst{ .mov_rr = .{
                .dst = dst,
                .src = prod.toReg(),
                .size = .size32,
            } };
            try ctx.emit(mov);
            return mov;
        },
    }
}

/// Constructor: sadd_overflow_trap - signed add with overflow trap.
/// Emits ADDS to set overflow flag, B.VC to skip trap, UDF to trap on overflow.
pub fn aarch64_sadd_overflow_trap(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    code: TrapCode,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_a = try ctx.getValueReg(a, .int);
    const reg_b = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    // ADDS dst, a, b (sets overflow flag on signed overflow)
    const inst = Inst{ .adds_rr = .{
        .dst = dst,
        .src1 = reg_a,
        .src2 = reg_b,
        .size = size,
    } };
    try ctx.emit(inst);

    // Skip trap if no overflow; skip next instruction (UDF).
    try ctx.emit(.{ .b_cond = .{
        .cond = .vc,
        .target = .{ .offset = 8 },
    } });

    // UDF (trap on overflow)
    try ctx.emit(.{ .udf = .{
        .imm = @intCast(code.toRaw()),
    } });
    return inst;
}

/// Constructor: ssub_overflow_trap - signed subtract with overflow trap.
/// Emits SUBS to set overflow flag, B.VC to skip trap, UDF to trap on overflow.
pub fn aarch64_ssub_overflow_trap(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    code: TrapCode,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_a = try ctx.getValueReg(a, .int);
    const reg_b = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    // SUBS dst, a, b (sets overflow flag on signed overflow)
    const inst = Inst{ .subs_rr = .{
        .dst = dst,
        .src1 = reg_a,
        .src2 = reg_b,
        .size = size,
    } };
    try ctx.emit(inst);

    // Skip trap if no overflow; skip next instruction (UDF).
    try ctx.emit(.{ .b_cond = .{
        .cond = .vc,
        .target = .{ .offset = 8 },
    } });

    // UDF (trap on overflow)
    try ctx.emit(.{ .udf = .{
        .imm = @intCast(code.toRaw()),
    } });
    return inst;
}

/// Constructor: smul_overflow_trap - signed multiply with overflow trap.
/// Uses SMULH to get high bits, checks if they match sign extension of low bits.
pub fn aarch64_smul_overflow_trap(
    ctx: *IsleContext,
    ty: Type,
    a: Value,
    b: Value,
    code: TrapCode,
) !Inst {
    const size = ctx.typeToSize(ty);
    const reg_a = try ctx.getValueReg(a, .int);
    const reg_b = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    switch (size) {
        .size64 => {
            const mul = Inst{ .mul_rr = .{
                .dst = dst,
                .src1 = reg_a,
                .src2 = reg_b,
                .size = .size64,
            } };
            try ctx.emit(mul);

            const high = ctx.allocOutputReg(.int);
            try ctx.emit(.{ .smulh = .{
                .dst = high,
                .src1 = reg_a,
                .src2 = reg_b,
            } });

            const sign_ext = ctx.allocOutputReg(.int);
            try ctx.emit(.{ .asr_imm = .{
                .dst = sign_ext,
                .src = dst.toReg(),
                .imm = 63,
                .size = .size64,
            } });

            try ctx.emit(.{ .cmp_rr = .{
                .src1 = high.toReg(),
                .src2 = sign_ext.toReg(),
                .size = .size64,
            } });

            // Skip trap if high == sign_ext; skip next instruction (UDF).
            try ctx.emit(.{ .b_cond = .{
                .cond = .eq,
                .target = .{ .offset = 8 },
            } });

            try ctx.emit(.{ .udf = .{ .imm = @intCast(code.toRaw()) } });
            return mul;
        },
        .size32 => {
            const prod = ctx.allocOutputReg(.int);
            try ctx.emit(.{ .smull = .{
                .dst = prod,
                .src1 = reg_a,
                .src2 = reg_b,
            } });

            const sign_ext = ctx.allocOutputReg(.int);
            try ctx.emit(.{ .sxtw = .{
                .dst = sign_ext,
                .src = prod.toReg(),
            } });

            try ctx.emit(.{ .cmp_rr = .{
                .src1 = prod.toReg(),
                .src2 = sign_ext.toReg(),
                .size = .size64,
            } });

            // Skip trap if prod == sign_ext; skip next instruction (UDF).
            try ctx.emit(.{ .b_cond = .{
                .cond = .eq,
                .target = .{ .offset = 8 },
            } });

            try ctx.emit(.{ .udf = .{ .imm = @intCast(code.toRaw()) } });

            const mov = Inst{ .mov_rr = .{
                .dst = dst,
                .src = prod.toReg(),
                .size = .size32,
            } };
            try ctx.emit(mov);
            return mov;
        },
    }
}

const SatOp = enum { add, sub };

fn satSignedNarrow(
    ctx: *IsleContext,
    dst: WritableReg,
    a: Value,
    b: Value,
    bits: u6,
    op: SatOp,
) !Inst {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);

    const a_ext = WritableReg.fromReg(ctx.allocInputReg(.int));
    const b_ext = WritableReg.fromReg(ctx.allocInputReg(.int));

    switch (bits) {
        8 => {
            try ctx.emit(.{ .sxtb = .{ .dst = a_ext, .src = a_reg, .dst_size = .size32 } });
            try ctx.emit(.{ .sxtb = .{ .dst = b_ext, .src = b_reg, .dst_size = .size32 } });
        },
        16 => {
            try ctx.emit(.{ .sxth = .{ .dst = a_ext, .src = a_reg, .dst_size = .size32 } });
            try ctx.emit(.{ .sxth = .{ .dst = b_ext, .src = b_reg, .dst_size = .size32 } });
        },
        else => return error.Unimplemented,
    }

    const alu: Inst = switch (op) {
        .add => .{ .add_rr = .{ .dst = dst, .src1 = a_ext.toReg(), .src2 = b_ext.toReg(), .size = .size32 } },
        .sub => .{ .sub_rr = .{ .dst = dst, .src1 = a_ext.toReg(), .src2 = b_ext.toReg(), .size = .size32 } },
    };
    try ctx.emit(alu);

    const max_i32: i32 = switch (bits) {
        8 => std.math.maxInt(i8),
        16 => std.math.maxInt(i16),
        else => unreachable,
    };
    const min_i32: i32 = switch (bits) {
        8 => std.math.minInt(i8),
        16 => std.math.minInt(i16),
        else => unreachable,
    };
    const max_u32: u32 = @bitCast(max_i32);
    const min_u32: u32 = @bitCast(min_i32);
    const max_imm: u64 = @as(u64, max_u32);
    const min_imm: u64 = @as(u64, min_u32);

    const max_reg = WritableReg.fromReg(ctx.allocInputReg(.int));
    try ctx.emit(.{ .mov_imm = .{ .dst = max_reg, .imm = max_imm, .size = .size32 } });
    try ctx.emit(.{ .cmp_rr = .{ .src1 = dst.toReg(), .src2 = max_reg.toReg(), .size = .size32 } });
    try ctx.emit(.{ .csel = .{
        .dst = dst,
        .src1 = max_reg.toReg(),
        .src2 = dst.toReg(),
        .cond = .gt,
        .size = .size32,
    } });

    const min_reg = WritableReg.fromReg(ctx.allocInputReg(.int));
    try ctx.emit(.{ .mov_imm = .{ .dst = min_reg, .imm = min_imm, .size = .size32 } });
    try ctx.emit(.{ .cmp_rr = .{ .src1 = dst.toReg(), .src2 = min_reg.toReg(), .size = .size32 } });
    const inst = Inst{ .csel = .{
        .dst = dst,
        .src1 = min_reg.toReg(),
        .src2 = dst.toReg(),
        .cond = .lt,
        .size = .size32,
    } };
    try ctx.emit(inst);
    return inst;
}

fn satUnsignedNarrow(
    ctx: *IsleContext,
    dst: WritableReg,
    a: Value,
    b: Value,
    bits: u6,
    op: SatOp,
) !Inst {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);

    const a_ext = WritableReg.fromReg(ctx.allocInputReg(.int));
    const b_ext = WritableReg.fromReg(ctx.allocInputReg(.int));

    switch (bits) {
        8 => {
            try ctx.emit(.{ .uxtb = .{ .dst = a_ext, .src = a_reg, .dst_size = .size32 } });
            try ctx.emit(.{ .uxtb = .{ .dst = b_ext, .src = b_reg, .dst_size = .size32 } });
        },
        16 => {
            try ctx.emit(.{ .uxth = .{ .dst = a_ext, .src = a_reg, .dst_size = .size32 } });
            try ctx.emit(.{ .uxth = .{ .dst = b_ext, .src = b_reg, .dst_size = .size32 } });
        },
        else => return error.Unimplemented,
    }

    switch (op) {
        .add => {
            try ctx.emit(.{ .add_rr = .{ .dst = dst, .src1 = a_ext.toReg(), .src2 = b_ext.toReg(), .size = .size32 } });

            const max_u32: u32 = switch (bits) {
                8 => std.math.maxInt(u8),
                16 => std.math.maxInt(u16),
                else => unreachable,
            };
            const max_reg = WritableReg.fromReg(ctx.allocInputReg(.int));
            try ctx.emit(.{ .mov_imm = .{ .dst = max_reg, .imm = @as(u64, max_u32), .size = .size32 } });
            try ctx.emit(.{ .cmp_rr = .{ .src1 = dst.toReg(), .src2 = max_reg.toReg(), .size = .size32 } });
            const inst = Inst{ .csel = .{
                .dst = dst,
                .src1 = max_reg.toReg(),
                .src2 = dst.toReg(),
                .cond = .hi,
                .size = .size32,
            } };
            try ctx.emit(inst);
            return inst;
        },
        .sub => {
            try ctx.emit(.{ .subs_rr = .{ .dst = dst, .src1 = a_ext.toReg(), .src2 = b_ext.toReg(), .size = .size32 } });
            const zero_reg = WritableReg.fromReg(ctx.allocInputReg(.int));
            try ctx.emit(.{ .mov_imm = .{ .dst = zero_reg, .imm = 0, .size = .size32 } });
            const inst = Inst{ .csel = .{
                .dst = dst,
                .src1 = dst.toReg(),
                .src2 = zero_reg.toReg(),
                .cond = .cs,
                .size = .size32,
            } };
            try ctx.emit(inst);
            return inst;
        },
    }
}

/// Constructor: sqadd_8 - signed saturating add for I8.
pub fn aarch64_sqadd_8(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const dst = ctx.allocOutputReg(.int);
    return satSignedNarrow(ctx, dst, a, b, 8, .add);
}

/// Constructor: sqadd_16 - signed saturating add for I16.
pub fn aarch64_sqadd_16(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const dst = ctx.allocOutputReg(.int);
    return satSignedNarrow(ctx, dst, a, b, 16, .add);
}

/// Constructor: sqadd_32 - signed saturating add for I32.
pub fn aarch64_sqadd_32(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .sqadd = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size32,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: sqadd_64 - signed saturating add for I64.
pub fn aarch64_sqadd_64(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .sqadd = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size64,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: sqsub_8 - signed saturating subtract for I8.
pub fn aarch64_sqsub_8(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const dst = ctx.allocOutputReg(.int);
    return satSignedNarrow(ctx, dst, a, b, 8, .sub);
}

/// Constructor: sqsub_16 - signed saturating subtract for I16.
pub fn aarch64_sqsub_16(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const dst = ctx.allocOutputReg(.int);
    return satSignedNarrow(ctx, dst, a, b, 16, .sub);
}

/// Constructor: sqsub_32 - signed saturating subtract for I32.
pub fn aarch64_sqsub_32(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .sqsub = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size32,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: sqsub_64 - signed saturating subtract for I64.
pub fn aarch64_sqsub_64(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .sqsub = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size64,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: uqadd_8 - unsigned saturating add for I8.
pub fn aarch64_uqadd_8(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const dst = ctx.allocOutputReg(.int);
    return satUnsignedNarrow(ctx, dst, a, b, 8, .add);
}

/// Constructor: uqadd_16 - unsigned saturating add for I16.
pub fn aarch64_uqadd_16(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const dst = ctx.allocOutputReg(.int);
    return satUnsignedNarrow(ctx, dst, a, b, 16, .add);
}

/// Constructor: uqadd_32 - unsigned saturating add for I32.
pub fn aarch64_uqadd_32(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .uqadd = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size32,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: uqadd_64 - unsigned saturating add for I64.
pub fn aarch64_uqadd_64(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .uqadd = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size64,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: uqsub_8 - unsigned saturating subtract for I8.
pub fn aarch64_uqsub_8(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const dst = ctx.allocOutputReg(.int);
    return satUnsignedNarrow(ctx, dst, a, b, 8, .sub);
}

/// Constructor: uqsub_16 - unsigned saturating subtract for I16.
pub fn aarch64_uqsub_16(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const dst = ctx.allocOutputReg(.int);
    return satUnsignedNarrow(ctx, dst, a, b, 16, .sub);
}

/// Constructor: uqsub_32 - unsigned saturating subtract for I32.
pub fn aarch64_uqsub_32(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .uqsub = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size32,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: uqsub_64 - unsigned saturating subtract for I64.
pub fn aarch64_uqsub_64(ctx: *IsleContext, a: Value, b: Value) !Inst {
    const a_reg = try ctx.getValueReg(a, .int);
    const b_reg = try ctx.getValueReg(b, .int);
    const dst = ctx.allocOutputReg(.int);

    const inst = Inst{ .uqsub = .{
        .dst = dst,
        .src1 = a_reg,
        .src2 = b_reg,
        .size = .size64,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: casal - compare-and-swap with acquire-release semantics.
/// Used for seq_cst atomic operations.
pub fn aarch64_casal(
    ctx: *IsleContext,
    addr: Value,
    expected: Value,
    new_val: Value,
) !void {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const expected_reg = try ctx.getValueReg(expected, .int);
    const new_val_reg = try ctx.getValueReg(new_val, .int);
    const dst = ctx.allocOutputReg(.int);

    try ctx.emit(Inst{ .casal = .{
        .compare = expected_reg,
        .swap = new_val_reg,
        .dst = dst,
        .base = addr_reg,
        .size = .size64,
    } });
}

/// Constructor: ldadd - atomic add (LSE).
/// Constructor: ldadd - atomic add using LL/SC fallback.
/// Emits LDXR/ADD/STXR loop for atomicity.
pub fn aarch64_ldadd(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    // Allocate retry label
    const retry_label = ctx.lower_ctx.allocLabel();

    // Bind retry label
    ctx.lower_ctx.bindLabel(retry_label);

    // LDXR old, [addr]
    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    // ADD new, old, val
    try ctx.emit(.{ .add_rr = .{
        .dst = WritableReg.fromReg(new),
        .src1 = old.toReg(),
        .src2 = val_reg,
        .size = .size64,
    } });

    // STXR status, new, [addr]
    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    // CBNZ status, retry
    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldclr - atomic clear using LL/SC fallback.
/// Emits LDXR/BIC/STXR loop. val is already inverted by caller.
pub fn aarch64_ldclr(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    // BIC new, old, val (clear bits)
    try ctx.emit(.{ .bic_rr = .{
        .dst = WritableReg.fromReg(new),
        .src1 = old.toReg(),
        .src2 = val_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldset - atomic set using LL/SC fallback.
/// Emits LDXR/ORR/STXR loop.
pub fn aarch64_ldset(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .orr_rr = .{
        .dst = WritableReg.fromReg(new),
        .src1 = old.toReg(),
        .src2 = val_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldeor - atomic XOR using LL/SC fallback.
/// Emits LDXR/EOR/STXR loop.
pub fn aarch64_ldeor(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .eor_rr = .{
        .dst = WritableReg.fromReg(new),
        .src1 = old.toReg(),
        .src2 = val_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: swpal - atomic exchange using LL/SC fallback.
/// Emits LDXR/STXR loop with no operation (just exchange).
pub fn aarch64_swpal(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = val_reg,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldsmax - atomic signed max using LL/SC fallback.
/// Emits LDXR/CMP/CSEL/STXR loop.
pub fn aarch64_ldsmax(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    // CMP old, val
    try ctx.emit(.{ .cmp_rr = .{
        .rn = old.toReg(),
        .rm = val_reg,
        .size = .size64,
    } });

    // CSEL new, old, val, GT (if old > val, keep old, else use val)
    try ctx.emit(.{ .csel = .{
        .dst = WritableReg.fromReg(new),
        .true_reg = old.toReg(),
        .false_reg = val_reg,
        .cond = .gt,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldsmin - atomic signed min using LL/SC fallback.
/// Emits LDXR/CMP/CSEL/STXR loop.
pub fn aarch64_ldsmin(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    // CMP old, val
    try ctx.emit(.{ .cmp_rr = .{
        .rn = old.toReg(),
        .rm = val_reg,
        .size = .size64,
    } });

    // CSEL new, old, val, LT (if old < val, keep old, else use val)
    try ctx.emit(.{ .csel = .{
        .dst = WritableReg.fromReg(new),
        .true_reg = old.toReg(),
        .false_reg = val_reg,
        .cond = .lt,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldumax - atomic unsigned max using LL/SC fallback.
/// Emits LDXR/CMP/CSEL/STXR loop.
pub fn aarch64_ldumax(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    // CMP old, val
    try ctx.emit(.{ .cmp_rr = .{
        .rn = old.toReg(),
        .rm = val_reg,
        .size = .size64,
    } });

    // CSEL new, old, val, HI (unsigned >)
    try ctx.emit(.{ .csel = .{
        .dst = WritableReg.fromReg(new),
        .true_reg = old.toReg(),
        .false_reg = val_reg,
        .cond = .hi,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: ldumin - atomic unsigned min using LL/SC fallback.
/// Emits LDXR/CMP/CSEL/STXR loop.
pub fn aarch64_ldumin(
    ctx: *IsleContext,
    addr: Value,
    val: Value,
) !WritableReg {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const val_reg = try ctx.getValueReg(val, .int);
    const old = ctx.allocOutputReg(.int);
    const new = ctx.allocInputReg(.int);
    const status = ctx.allocInputReg(.int);

    const retry_label = ctx.lower_ctx.allocLabel();
    ctx.lower_ctx.bindLabel(retry_label);

    try ctx.emit(.{ .ldxr = .{
        .dst = old,
        .base = addr_reg,
        .size = .size64,
    } });

    // CMP old, val
    try ctx.emit(.{ .cmp_rr = .{
        .rn = old.toReg(),
        .rm = val_reg,
        .size = .size64,
    } });

    // CSEL new, old, val, LO (unsigned <)
    try ctx.emit(.{ .csel = .{
        .dst = WritableReg.fromReg(new),
        .true_reg = old.toReg(),
        .false_reg = val_reg,
        .cond = .cc,
        .size = .size64,
    } });

    try ctx.emit(.{ .stxr = .{
        .status = WritableReg.fromReg(status),
        .src = new,
        .base = addr_reg,
        .size = .size64,
    } });

    try ctx.emit(.{ .cbnz = .{
        .reg = status,
        .target = .{ .label = retry_label },
        .size = .size32,
    } });

    return old;
}

/// Constructor: aarch64_istore8 - Store 8-bit value (STRB).
pub fn aarch64_istore8(
    ctx: *IsleContext,
    val: Value,
    addr: Value,
) !Inst {
    const val_reg = try ctx.getValueReg(val, .int);
    const addr_reg = try ctx.getValueReg(addr, .int);

    return Inst{ .strb = .{
        .src = val_reg,
        .base = addr_reg,
        .offset = 0,
    } };
}

/// Constructor: aarch64_istore16 - Store 16-bit value (STRH).
pub fn aarch64_istore16(
    ctx: *IsleContext,
    val: Value,
    addr: Value,
) !Inst {
    const val_reg = try ctx.getValueReg(val, .int);
    const addr_reg = try ctx.getValueReg(addr, .int);

    return Inst{ .strh = .{
        .src = val_reg,
        .base = addr_reg,
        .offset = 0,
    } };
}

/// Constructor: aarch64_istore32 - Store 32-bit value (STR Wd).
pub fn aarch64_istore32(
    ctx: *IsleContext,
    val: Value,
    addr: Value,
) !Inst {
    const val_reg = try ctx.getValueReg(val, .int);
    const addr_reg = try ctx.getValueReg(addr, .int);

    return Inst{ .str = .{
        .src = val_reg,
        .base = addr_reg,
        .offset = 0,
        .size = .size32,
    } };
}

/// Constructor: aarch64_vstr - Store vector value (STR Qt/Dt).
pub fn aarch64_vstr(
    ctx: *IsleContext,
    val: Value,
    addr: Value,
) !Inst {
    const ty = try ctx.lower_ctx.getValueType(val);
    const size: FpuOperandSize = switch (ty.bits()) {
        32 => .size32,
        64 => .size64,
        128 => .size128,
        else => return error.Unimplemented,
    };

    const val_reg = try ctx.getValueReg(val, .vector);
    const addr_reg = try ctx.getValueReg(addr, .int);

    return Inst{ .vstr = .{
        .src = val_reg,
        .base = addr_reg,
        .offset = 0,
        .size = size,
    } };
}

/// Constructor: aarch64_snarrow - Signed saturating narrow (SQXTN).
/// Narrows wider elements to narrower with signed saturation.
pub fn aarch64_snarrow(
    ctx: *IsleContext,
    size: isle_helpers.VectorSize,
    src: Value,
) !Inst {
    const src_reg = try ctx.getValueReg(src, .float);
    const dst = ctx.allocOutputReg(.float);

    // Map VectorSize to VecElemSize for output
    const elem_size: Inst.VecElemSize = switch (size) {
        .V8B => .size8x8, // 16x8b -> 8x8b
        .V16B => .size8x16, // 16x8b -> 8x16b (SQXTN2)
        .V4H => .size16x4, // 8x16b -> 4x16b
        .V8H => .size16x8, // 8x16b -> 8x16b (SQXTN2)
        .V2S => .size32x2, // 4x32b -> 2x32b
        .V4S => .size32x4, // 4x32b -> 4x32b (SQXTN2)
        .V2D => unreachable, // No 64->32 narrow with 2D output
    };

    const high = switch (size) {
        .V16B, .V8H, .V4S => true, // SQXTN2 (write high half)
        .V8B, .V4H, .V2S => false, // SQXTN (write low half)
        .V2D => unreachable,
    };

    return Inst{ .vec_sqxtn = .{
        .dst = dst,
        .src = src_reg,
        .size = elem_size,
        .high = high,
    } };
}

/// Constructor: aarch64_unarrow - Signed to unsigned saturating narrow (SQXTUN).
/// Narrows signed wider elements to unsigned narrower with saturation.
pub fn aarch64_unarrow(
    ctx: *IsleContext,
    size: isle_helpers.VectorSize,
    src: Value,
) !Inst {
    const src_reg = try ctx.getValueReg(src, .float);
    const dst = ctx.allocOutputReg(.float);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V8B => .size8x8,
        .V16B => .size8x16,
        .V4H => .size16x4,
        .V8H => .size16x8,
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => unreachable,
    };

    const high = switch (size) {
        .V16B, .V8H, .V4S => true,
        .V8B, .V4H, .V2S => false,
        .V2D => unreachable,
    };

    return Inst{ .vec_sqxtun = .{
        .dst = dst,
        .src = src_reg,
        .size = elem_size,
        .high = high,
    } };
}

/// Constructor: aarch64_uunarrow - Unsigned saturating narrow (UQXTN).
/// Narrows unsigned wider elements to unsigned narrower with saturation.
pub fn aarch64_uunarrow(
    ctx: *IsleContext,
    size: isle_helpers.VectorSize,
    src: Value,
) !Inst {
    const src_reg = try ctx.getValueReg(src, .float);
    const dst = ctx.allocOutputReg(.float);

    const elem_size: Inst.VecElemSize = switch (size) {
        .V8B => .size8x8,
        .V16B => .size8x16,
        .V4H => .size16x4,
        .V8H => .size16x8,
        .V2S => .size32x2,
        .V4S => .size32x4,
        .V2D => unreachable,
    };

    const high = switch (size) {
        .V16B, .V8H, .V4S => true,
        .V8B, .V4H, .V2S => false,
        .V2D => unreachable,
    };

    return Inst{ .vec_uqxtn = .{
        .dst = dst,
        .src = src_reg,
        .size = elem_size,
        .high = high,
    } };
}

/// Constructor: aarch64_vldr - Load vector (LDR Qt/Dt).
pub fn aarch64_vldr(
    ctx: *IsleContext,
    ty: Type,
    addr: Value,
) !Inst {
    const addr_reg = try ctx.getValueReg(addr, .int);
    const dst = ctx.allocOutputReg(.vector);
    const size: FpuOperandSize = switch (ty.bits()) {
        32 => .size32,
        64 => .size64,
        128 => .size128,
        else => return error.UnsupportedVectorSize,
    };

    return Inst{ .vldr = .{
        .dst = dst,
        .base = addr_reg,
        .offset = 0,
        .size = size,
    } };
}

/// Constructor: aarch64_get_frame_pointer - Get frame pointer (X29/FP).
pub fn aarch64_get_frame_pointer(
    ctx: *IsleContext,
) !Inst {
    const dst = ctx.allocOutputReg(.int);
    const fp = Reg.gpr(29); // X29 is the frame pointer

    const inst = Inst{ .mov_rr = .{
        .dst = dst,
        .src = fp,
        .size = .size64,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: aarch64_get_stack_pointer - Get stack pointer (SP).
pub fn aarch64_get_stack_pointer(
    ctx: *IsleContext,
) !Inst {
    const dst = ctx.allocOutputReg(.int);
    const sp = Reg.gpr(31); // X31/SP is the stack pointer

    const inst = Inst{ .mov_rr = .{
        .dst = dst,
        .src = sp,
        .size = .size64,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: aarch64_get_return_address - Get return address (X30/LR).
pub fn aarch64_get_return_address(
    ctx: *IsleContext,
) !Inst {
    const dst = ctx.allocOutputReg(.int);
    const lr = Reg.gpr(30); // X30 is the link register

    const inst = Inst{ .mov_rr = .{
        .dst = dst,
        .src = lr,
        .size = .size64,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Constructor: aarch64_get_pinned_reg - Get platform pinned register.
/// X18 on Darwin (reserved by Apple), X28 elsewhere.
pub fn aarch64_get_pinned_reg(
    ctx: *IsleContext,
) !Inst {
    const dst = ctx.allocOutputReg(.int);
    const pinned = Reg.gpr(pinnedRegNum());

    const inst = Inst{ .mov_rr = .{
        .dst = dst,
        .src = pinned,
        .size = .size64,
    } };
    try ctx.emit(inst);
    return inst;
}

/// Get pinned register number based on platform.
/// Darwin reserves X18, so we use it there. Other platforms use X28.
fn pinnedRegNum() u6 {
    return switch (abi_mod.Platform.detect()) {
        .darwin => 18,
        .linux, .other => 28,
    };
}

/// Constructor: aarch64_set_pinned_reg - Set platform pinned register.
pub fn aarch64_set_pinned_reg(
    ctx: *IsleContext,
    val: Value,
) !Inst {
    const val_reg = try ctx.getValueReg(val, .int);
    const pinned = Reg.gpr(pinnedRegNum());

    return Inst{ .mov_rr = .{
        .dst = WritableReg.fromReg(pinned),
        .src = val_reg,
        .size = .size64,
    } };
}

/// Constructor: aarch64_landingpad - Read exception value from X0.
pub fn aarch64_landingpad(
    ctx: *IsleContext,
) !Inst {
    const dst = ctx.allocOutputReg(.int);
    // Exception pointer in X0 per AAPCS64 ABI
    return Inst{ .mov_rr = .{
        .dst = dst,
        .src = Reg.gpr(0),
        .size = .size64,
    } };
}

/// Constructor: aarch64_debugtrap - Emit debug trap (BRK).
pub fn aarch64_debugtrap(
    ctx: *IsleContext,
) !Inst {
    _ = ctx;
    return Inst{ .brk = .{ .imm = 0 } };
}

/// Emit Spectre mitigation fence (ISB instruction).
/// ISB (Instruction Synchronization Barrier) prevents speculative execution
/// across security boundaries, mitigating Spectre-style attacks.
pub fn aarch64_spectre_fence(
    ctx: *IsleContext,
) !Inst {
    _ = ctx;
    return Inst{ .isb = {} };
}
