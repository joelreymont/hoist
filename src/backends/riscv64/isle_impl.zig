const std = @import("std");
const root = @import("../../root.zig");

const Inst = @import("inst.zig").Inst;
const Reg = @import("inst.zig").Reg;
const WritableReg = @import("inst.zig").WritableReg;

const lower_mod = @import("../../machinst/lower.zig");
const LowerCtx = lower_mod.LowerCtx;
const ValueRegs = lower_mod.ValueRegs;
const Value = lower_mod.Value;
const Type = @import("../../ir/types.zig").Type;

const ir_externs = @import("../../dsl/isle/ir_externs.zig");

pub const IsleCtx = struct {
    lower_ctx: *LowerCtx(Inst),

    pub fn init(ctx: *LowerCtx(Inst)) IsleCtx {
        return .{ .lower_ctx = ctx };
    }

    pub fn emit(self: *IsleCtx, inst: Inst) !void {
        try self.lower_ctx.emit(inst);
    }

    pub fn getValueReg(self: *IsleCtx, value: Value, class: lower_mod.RegClass) !Reg {
        const vreg = try self.lower_ctx.getValueReg(value, class);
        return Reg.fromVReg(vreg);
    }

    pub fn allocOutputReg(self: *IsleCtx, class: lower_mod.RegClass) WritableReg {
        const vreg = self.lower_ctx.allocVReg(class);
        return WritableReg.fromVReg(vreg);
    }
};

const Ir = ir_externs.Externs(IsleCtx);

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
pub const symbol_value_data_ext = Ir.symbol_value_data_ext;

fn is32Bit(ty: Type) bool {
    return ty.bits() <= 32;
}

// Integer arithmetic

pub fn rv_add(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .addw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .add = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return ValueRegs.single(dst.toReg());
}

pub fn rv_sub(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .subw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .sub = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return ValueRegs.single(dst.toReg());
}

pub fn rv_mul(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .mulw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .mul = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return ValueRegs.single(dst.toReg());
}

pub fn rv_div(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .divw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .div = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return ValueRegs.single(dst.toReg());
}

pub fn rv_divu(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .divuw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .divu = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return ValueRegs.single(dst.toReg());
}

pub fn rv_rem(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .remw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .rem = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return ValueRegs.single(dst.toReg());
}

pub fn rv_remu(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .remuw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .remu = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return ValueRegs.single(dst.toReg());
}

pub fn rv_addi(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm: i12 = @intCast(k);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .addiw = .{ .dst = dst, .src = rx, .imm = imm } });
    } else {
        try ctx.emit(.{ .addi = .{ .dst = dst, .src = rx, .imm = imm } });
    }
    return ValueRegs.single(dst.toReg());
}

// Bitwise operations

pub fn rv_and(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);
    try ctx.emit(.{ .@"and" = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    return ValueRegs.single(dst.toReg());
}

pub fn rv_or(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);
    try ctx.emit(.{ .@"or" = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    return ValueRegs.single(dst.toReg());
}

pub fn rv_xor(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);
    try ctx.emit(.{ .xor = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    return ValueRegs.single(dst.toReg());
}

pub fn rv_andi(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !ValueRegs {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm: i12 = @intCast(k);
    try ctx.emit(.{ .andi = .{ .dst = dst, .src = rx, .imm = imm } });
    return ValueRegs.single(dst.toReg());
}

pub fn rv_ori(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !ValueRegs {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm: i12 = @intCast(k);
    try ctx.emit(.{ .ori = .{ .dst = dst, .src = rx, .imm = imm } });
    return ValueRegs.single(dst.toReg());
}

pub fn rv_xori(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !ValueRegs {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm: i12 = @intCast(k);
    try ctx.emit(.{ .xori = .{ .dst = dst, .src = rx, .imm = imm } });
    return ValueRegs.single(dst.toReg());
}

// Shifts

pub fn rv_sll(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .sllw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .sll = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return ValueRegs.single(dst.toReg());
}

pub fn rv_srl(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .srlw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .srl = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return ValueRegs.single(dst.toReg());
}

pub fn rv_sra(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        try ctx.emit(.{ .sraw = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    } else {
        try ctx.emit(.{ .sra = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    }
    return ValueRegs.single(dst.toReg());
}

pub fn rv_slli(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        const shamt: u5 = @intCast(@as(u64, @bitCast(k)) & 0x1f);
        try ctx.emit(.{ .slliw = .{ .dst = dst, .src = rx, .shamt = shamt } });
    } else {
        const shamt: u6 = @intCast(@as(u64, @bitCast(k)) & 0x3f);
        try ctx.emit(.{ .slli = .{ .dst = dst, .src = rx, .shamt = shamt } });
    }
    return ValueRegs.single(dst.toReg());
}

pub fn rv_srli(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        const shamt: u5 = @intCast(@as(u64, @bitCast(k)) & 0x1f);
        try ctx.emit(.{ .srliw = .{ .dst = dst, .src = rx, .shamt = shamt } });
    } else {
        const shamt: u6 = @intCast(@as(u64, @bitCast(k)) & 0x3f);
        try ctx.emit(.{ .srli = .{ .dst = dst, .src = rx, .shamt = shamt } });
    }
    return ValueRegs.single(dst.toReg());
}

pub fn rv_srai(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !ValueRegs {
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);

    if (is32Bit(ty)) {
        const shamt: u5 = @intCast(@as(u64, @bitCast(k)) & 0x1f);
        try ctx.emit(.{ .sraiw = .{ .dst = dst, .src = rx, .shamt = shamt } });
    } else {
        const shamt: u6 = @intCast(@as(u64, @bitCast(k)) & 0x3f);
        try ctx.emit(.{ .srai = .{ .dst = dst, .src = rx, .shamt = shamt } });
    }
    return ValueRegs.single(dst.toReg());
}

// Comparisons

pub fn rv_slt(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);
    try ctx.emit(.{ .slt = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    return ValueRegs.single(dst.toReg());
}

pub fn rv_sltu(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const ry = try ctx.getValueReg(y, .int);
    const dst = ctx.allocOutputReg(.int);
    try ctx.emit(.{ .sltu = .{ .dst = dst, .src1 = rx, .src2 = ry } });
    return ValueRegs.single(dst.toReg());
}

pub fn rv_slti(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !ValueRegs {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm: i12 = @intCast(k);
    try ctx.emit(.{ .slti = .{ .dst = dst, .src = rx, .imm = imm } });
    return ValueRegs.single(dst.toReg());
}

pub fn rv_sltiu(ctx: *IsleCtx, ty: Type, x: Value, k: i64) !ValueRegs {
    _ = ty;
    const rx = try ctx.getValueReg(x, .int);
    const dst = ctx.allocOutputReg(.int);
    const imm: i12 = @intCast(k);
    try ctx.emit(.{ .sltiu = .{ .dst = dst, .src = rx, .imm = imm } });
    return ValueRegs.single(dst.toReg());
}

// Stubs for remaining constructors (to be implemented)

pub fn rv_load(ctx: *IsleCtx, ty: Type, addr: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_store(ctx: *IsleCtx, val: Value, addr: Value) !ValueRegs {
    _ = ctx;
    _ = val;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_jmp(ctx: *IsleCtx, target: lower_mod.Block) !ValueRegs {
    _ = ctx;
    _ = target;
    return error.Unimplemented;
}

pub fn rv_brif(ctx: *IsleCtx, cond: Value, target: lower_mod.Block) !ValueRegs {
    _ = ctx;
    _ = cond;
    _ = target;
    return error.Unimplemented;
}

pub fn rv_ret(ctx: *IsleCtx) !ValueRegs {
    try ctx.emit(.ret);
    return ValueRegs.single(Reg.invalid());
}

pub fn rv_iconst(ctx: *IsleCtx, ty: Type, k: i64) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = k;
    return error.Unimplemented;
}

pub fn rv_fadd(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fsub(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fmul(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fdiv(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fsqrt(ctx: *IsleCtx, ty: Type, x: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_fmin(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fmax(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_feq(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_flt(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fle(ctx: *IsleCtx, ty: Type, x: Value, y: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    _ = y;
    return error.Unimplemented;
}

pub fn rv_fcvt_from_sint(ctx: *IsleCtx, ty: Type, x: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_fcvt_from_uint(ctx: *IsleCtx, ty: Type, x: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_fcvt_to_sint(ctx: *IsleCtx, ty: Type, x: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_fcvt_to_uint(ctx: *IsleCtx, ty: Type, x: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_fcvt_s_d(ctx: *IsleCtx, x: Value) !ValueRegs {
    _ = ctx;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_fcvt_d_s(ctx: *IsleCtx, x: Value) !ValueRegs {
    _ = ctx;
    _ = x;
    return error.Unimplemented;
}

pub fn rv_flw(ctx: *IsleCtx, addr: Value) !ValueRegs {
    _ = ctx;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_fld(ctx: *IsleCtx, addr: Value) !ValueRegs {
    _ = ctx;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_fsw(ctx: *IsleCtx, val: Value, addr: Value) !ValueRegs {
    _ = ctx;
    _ = val;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_fsd(ctx: *IsleCtx, val: Value, addr: Value) !ValueRegs {
    _ = ctx;
    _ = val;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_amoadd(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amoswap(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amoand(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amoor(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amoxor(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amomin(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amomax(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amominu(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_amomaxu(ctx: *IsleCtx, ty: Type, addr: Value, val: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = addr;
    _ = val;
    return error.Unimplemented;
}

pub fn rv_lr(ctx: *IsleCtx, ty: Type, addr: Value) !ValueRegs {
    _ = ctx;
    _ = ty;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_sc(ctx: *IsleCtx, val: Value, addr: Value) !ValueRegs {
    _ = ctx;
    _ = val;
    _ = addr;
    return error.Unimplemented;
}

pub fn rv_fence(ctx: *IsleCtx) !ValueRegs {
    _ = ctx;
    return error.Unimplemented;
}
