const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const OperandSize = root.aarch64_inst.OperandSize;
const VectorSize = root.aarch64_inst.VectorSize;
const CondCode = root.aarch64_inst.CondCode;
const Reg = root.aarch64_inst.Reg;
const PReg = root.aarch64_inst.PReg;
const buffer_mod = root.buffer;

/// Emit aarch64 instruction to binary.
/// This is a minimal bootstrap - full aarch64 emission needs:
/// - Complete instruction encoding with all formats
/// - Shifted/extended operand support
/// - Wide immediate materialization
/// - Vector instructions
pub fn emit(inst: Inst, buffer: *buffer_mod.MachBuffer) !void {
    switch (inst) {
        .mov_rr => |i| try emitMovRR(i.dst.toReg(), i.src, i.size, buffer),
        .mov_imm => |i| try emitMovImm(i.dst.toReg(), i.imm, i.size, buffer),
        .movz => |i| try emitMovz(i.dst.toReg(), i.imm, i.shift, i.size, buffer),
        .movk => |i| try emitMovk(i.dst.toReg(), i.imm, i.shift, i.size, buffer),
        .movn => |i| try emitMovn(i.dst.toReg(), i.imm, i.shift, i.size, buffer),
        .add_rr => |i| try emitAddRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .add_imm => |i| try emitAddImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .add_shifted => |i| try emitAddShifted(i.dst.toReg(), i.src1, i.src2, i.shift_op, i.shift_amt, i.size, buffer),
        .add_extended => |i| try emitAddExtended(i.dst.toReg(), i.src1, i.src2, i.extend_op, i.size, buffer),
        .sub_rr => |i| try emitSubRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .sub_imm => |i| try emitSubImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .mul_rr => |i| try emitMulRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .madd => |i| try emitMadd(i.dst.toReg(), i.src1, i.src2, i.addend, i.size, buffer),
        .msub => |i| try emitMsub(i.dst.toReg(), i.src1, i.src2, i.subtrahend, i.size, buffer),
        .smulh => |i| try emitSmulh(i.dst.toReg(), i.src1, i.src2, buffer),
        .umulh => |i| try emitUmulh(i.dst.toReg(), i.src1, i.src2, buffer),
        .smull => |i| try emitSmull(i.dst.toReg(), i.src1, i.src2, buffer),
        .umull => |i| try emitUmull(i.dst.toReg(), i.src1, i.src2, buffer),
        .sdiv => |i| try emitSdiv(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .udiv => |i| try emitUdiv(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .lsl_rr => |i| try emitLslRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .lsl_imm => |i| try emitLslImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .lsr_rr => |i| try emitLsrRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .lsr_imm => |i| try emitLsrImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .asr_rr => |i| try emitAsrRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .asr_imm => |i| try emitAsrImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .ror_rr => |i| try emitRorRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .ror_imm => |i| try emitRorImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .and_rr => |i| try emitAndRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .and_imm => |i| try emitAndImm(i.dst.toReg(), i.src, i.imm, buffer),
        .orr_rr => |i| try emitOrrRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .orr_imm => |i| try emitOrrImm(i.dst.toReg(), i.src, i.imm, buffer),
        .eor_rr => |i| try emitEorRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .eor_imm => |i| try emitEorImm(i.dst.toReg(), i.src, i.imm, buffer),
        .mvn_rr => |i| try emitMvnRR(i.dst.toReg(), i.src, i.size, buffer),
        .neg => |i| try emitNeg(i.dst.toReg(), i.src, i.size, buffer),
        .ngc => |i| try emitNgc(i.dst.toReg(), i.src, i.size, buffer),
        .adds_rr => |i| try emitAddsRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .adds_imm => |i| try emitAddsImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .subs_rr => |i| try emitSubsRR(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .subs_imm => |i| try emitSubsImm(i.dst.toReg(), i.src, i.imm, i.size, buffer),
        .cmp_rr => |i| try emitCmpRR(i.src1, i.src2, i.size, buffer),
        .cmp_imm => |i| try emitCmpImm(i.src, i.imm, i.size, buffer),
        .cmn_rr => |i| try emitCmnRR(i.src1, i.src2, i.size, buffer),
        .cmn_imm => |i| try emitCmnImm(i.src, i.imm, i.size, buffer),
        .tst_rr => |i| try emitTstRR(i.src1, i.src2, i.size, buffer),
        .tst_imm => |i| try emitTstImm(i.src, i.imm, buffer),
        .clz => |i| try emitClz(i.dst.toReg(), i.src, i.size, buffer),
        .cls => |i| try emitCls(i.dst.toReg(), i.src, i.size, buffer),
        .rbit => |i| try emitRbit(i.dst.toReg(), i.src, i.size, buffer),
        .csel => |i| try emitCsel(i.dst.toReg(), i.src1, i.src2, i.cond, i.size, buffer),
        .csinc => |i| try emitCsinc(i.dst.toReg(), i.src1, i.src2, i.cond, i.size, buffer),
        .csinv => |i| try emitCsinv(i.dst.toReg(), i.src1, i.src2, i.cond, i.size, buffer),
        .csneg => |i| try emitCsneg(i.dst.toReg(), i.src1, i.src2, i.cond, i.size, buffer),
        .sxtb => |i| try emitSxtb(i.dst.toReg(), i.src, i.size, buffer),
        .sxth => |i| try emitSxth(i.dst.toReg(), i.src, i.size, buffer),
        .sxtw => |i| try emitSxtw(i.dst.toReg(), i.src, buffer),
        .uxtb => |i| try emitUxtb(i.dst.toReg(), i.src, i.size, buffer),
        .uxth => |i| try emitUxth(i.dst.toReg(), i.src, i.size, buffer),
        .ldr => |i| try emitLdr(i.dst.toReg(), i.base, i.offset, i.size, buffer),
        .ldr_reg => |i| try emitLdrReg(i.dst.toReg(), i.base, i.offset, i.size, buffer),
        .ldr_ext => |i| try emitLdrExt(i.dst.toReg(), i.base, i.offset, i.extend, i.size, buffer),
        .ldr_shifted => |i| try emitLdrShifted(i.dst.toReg(), i.base, i.offset, i.shift_op, i.shift_amt, i.size, buffer),
        .str => |i| try emitStr(i.src, i.base, i.offset, i.size, buffer),
        .str_reg => |i| try emitStrReg(i.src, i.base, i.offset, i.size, buffer),
        .str_ext => |i| try emitStrExt(i.src, i.base, i.offset, i.extend, i.size, buffer),
        .str_shifted => |i| try emitStrShifted(i.src, i.base, i.offset, i.shift_op, i.shift_amt, i.size, buffer),
        .ldrb => |i| try emitLdrb(i.dst.toReg(), i.base, i.offset, i.size, buffer),
        .ldrh => |i| try emitLdrh(i.dst.toReg(), i.base, i.offset, i.size, buffer),
        .ldrsb => |i| try emitLdrsb(i.dst.toReg(), i.base, i.offset, i.size, buffer),
        .ldrsh => |i| try emitLdrsh(i.dst.toReg(), i.base, i.offset, i.size, buffer),
        .ldrsw => |i| try emitLdrsw(i.dst.toReg(), i.base, i.offset, buffer),
        .strb => |i| try emitStrb(i.src, i.base, i.offset, buffer),
        .strh => |i| try emitStrh(i.src, i.base, i.offset, buffer),
        .stp => |i| try emitStp(i.src1, i.src2, i.base, i.offset, i.size, buffer),
        .ldp => |i| try emitLdp(i.dst1.toReg(), i.dst2.toReg(), i.base, i.offset, i.size, buffer),
        .ldr_pre => |i| try emitLdrPre(i.dst.toReg(), i.base.toReg(), i.offset, i.size, buffer),
        .ldr_post => |i| try emitLdrPost(i.dst.toReg(), i.base.toReg(), i.offset, i.size, buffer),
        .str_pre => |i| try emitStrPre(i.src, i.base.toReg(), i.offset, i.size, buffer),
        .str_post => |i| try emitStrPost(i.src, i.base.toReg(), i.offset, i.size, buffer),
        .ldarb => |i| try emitLdarb(i.dst.toReg(), i.base, buffer),
        .ldarh => |i| try emitLdarh(i.dst.toReg(), i.base, buffer),
        .ldar_w => |i| try emitLdarW(i.dst.toReg(), i.base, buffer),
        .ldar_x => |i| try emitLdarX(i.dst.toReg(), i.base, buffer),
        .stlrb => |i| try emitStlrb(i.src, i.base, buffer),
        .stlrh => |i| try emitStlrh(i.src, i.base, buffer),
        .stlr_w => |i| try emitStlrW(i.src, i.base, buffer),
        .stlr_x => |i| try emitStlrX(i.src, i.base, buffer),
        .ldxr_w => |i| try emitLdxrW(i.dst.toReg(), i.base, buffer),
        .ldxr_x => |i| try emitLdxrX(i.dst.toReg(), i.base, buffer),
        .ldxrb => |i| try emitLdxrb(i.dst.toReg(), i.base, buffer),
        .ldxrh => |i| try emitLdxrh(i.dst.toReg(), i.base, buffer),
        .stxr_w => |i| try emitStxrW(i.status.toReg(), i.src, i.base, buffer),
        .stxr_x => |i| try emitStxrX(i.status.toReg(), i.src, i.base, buffer),
        .stxrb => |i| try emitStxrb(i.status.toReg(), i.src, i.base, buffer),
        .stxrh => |i| try emitStxrh(i.status.toReg(), i.src, i.base, buffer),
        .ldaxr_w => |i| try emitLdaxrW(i.dst.toReg(), i.base, buffer),
        .ldaxr_x => |i| try emitLdaxrX(i.dst.toReg(), i.base, buffer),
        .ldaxrb => |i| try emitLdaxrb(i.dst.toReg(), i.base, buffer),
        .ldaxrh => |i| try emitLdaxrh(i.dst.toReg(), i.base, buffer),
        .stlxr_w => |i| try emitStlxrW(i.status.toReg(), i.src, i.base, buffer),
        .stlxr_x => |i| try emitStlxrX(i.status.toReg(), i.src, i.base, buffer),
        .stlxrb => |i| try emitStlxrb(i.status.toReg(), i.src, i.base, buffer),
        .stlxrh => |i| try emitStlxrh(i.status.toReg(), i.src, i.base, buffer),
        .ldadd => |i| try emitLdadd(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldadda => |i| try emitLdadda(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldaddal => |i| try emitLdaddal(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldaddl => |i| try emitLdaddl(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldclr => |i| try emitLdclr(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldclra => |i| try emitLdclra(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldclral => |i| try emitLdclral(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldclrl => |i| try emitLdclrl(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldset => |i| try emitLdset(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldseta => |i| try emitLdseta(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldsetal => |i| try emitLdsetal(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldsetl => |i| try emitLdsetl(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldeor => |i| try emitLdeor(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldeora => |i| try emitLdeora(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldeoral => |i| try emitLdeoral(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .ldeorl => |i| try emitLdeorl(i.dst.toReg(), i.src, i.base, i.size, buffer),
        .cas => |i| try emitCas(i.compare, i.src, i.base, i.size, buffer),
        .casa => |i| try emitCasa(i.compare, i.src, i.base, i.size, buffer),
        .casal => |i| try emitCasal(i.compare, i.src, i.base, i.size, buffer),
        .casl => |i| try emitCasl(i.compare, i.src, i.base, i.size, buffer),
        .dmb => |i| try emitDmb(i.option, buffer),
        .dsb => |i| try emitDsb(i.option, buffer),
        .isb => try emitIsb(buffer),
        .b => |i| try emitB(i.target.label, buffer),
        .b_cond => |i| try emitBCond(@intFromEnum(i.cond), i.target.label, buffer),
        .bl => |i| switch (i.target) {
            .direct => |_| @panic("External function calls not yet implemented"),
            .indirect => |reg| try emitBLR(reg, buffer),
        },
        .br => |i| try emitBR(i.target, buffer),
        .blr => |i| try emitBLR(i.target, buffer),
        .ret => |i| try emitRet(i.reg, buffer),
        .nop => try emitNop(buffer),
        .fadd_s => |i| try emitFaddS(i.dst.toReg(), i.src1, i.src2, buffer),
        .fadd_d => |i| try emitFaddD(i.dst.toReg(), i.src1, i.src2, buffer),
        .fsub_s => |i| try emitFsubS(i.dst.toReg(), i.src1, i.src2, buffer),
        .fsub_d => |i| try emitFsubD(i.dst.toReg(), i.src1, i.src2, buffer),
        .fmul_s => |i| try emitFmulS(i.dst.toReg(), i.src1, i.src2, buffer),
        .fmul_d => |i| try emitFmulD(i.dst.toReg(), i.src1, i.src2, buffer),
        .fdiv_s => |i| try emitFdivS(i.dst.toReg(), i.src1, i.src2, buffer),
        .fdiv_d => |i| try emitFdivD(i.dst.toReg(), i.src1, i.src2, buffer),
        .fmov_rr_s => |i| try emitFmovRRS(i.dst.toReg(), i.src, buffer),
        .fmov_rr_d => |i| try emitFmovRRD(i.dst.toReg(), i.src, buffer),
        .fmov_imm_s => |i| try emitFmovImmS(i.dst.toReg(), i.imm, buffer),
        .fmov_imm_d => |i| try emitFmovImmD(i.dst.toReg(), i.imm, buffer),
        .fcmp_s => |i| try emitFcmpS(i.src1, i.src2, buffer),
        .fcmp_d => |i| try emitFcmpD(i.src1, i.src2, buffer),
        .fcvt_s_to_d => |i| try emitFcvtSToD(i.dst.toReg(), i.src, buffer),
        .fcvt_d_to_s => |i| try emitFcvtDToS(i.dst.toReg(), i.src, buffer),
        .scvtf_w_to_s => |i| try emitScvtfWToS(i.dst.toReg(), i.src, buffer),
        .scvtf_x_to_s => |i| try emitScvtfXToS(i.dst.toReg(), i.src, buffer),
        .scvtf_w_to_d => |i| try emitScvtfWToD(i.dst.toReg(), i.src, buffer),
        .scvtf_x_to_d => |i| try emitScvtfXToD(i.dst.toReg(), i.src, buffer),
        .fcvtzs_s_to_w => |i| try emitFcvtzsSTow(i.dst.toReg(), i.src, buffer),
        .fcvtzs_s_to_x => |i| try emitFcvtzsSToX(i.dst.toReg(), i.src, buffer),
        .fcvtzs_d_to_w => |i| try emitFcvtzsDToW(i.dst.toReg(), i.src, buffer),
        .fcvtzs_d_to_x => |i| try emitFcvtzsDToX(i.dst.toReg(), i.src, buffer),
        .fneg_s => |i| try emitFnegS(i.dst.toReg(), i.src, buffer),
        .fneg_d => |i| try emitFnegD(i.dst.toReg(), i.src, buffer),
        .fabs_s => |i| try emitFabsS(i.dst.toReg(), i.src, buffer),
        .fabs_d => |i| try emitFabsD(i.dst.toReg(), i.src, buffer),
        .fmax_s => |i| try emitFmaxS(i.dst.toReg(), i.src1, i.src2, buffer),
        .fmax_d => |i| try emitFmaxD(i.dst.toReg(), i.src1, i.src2, buffer),
        .fmin_s => |i| try emitFminS(i.dst.toReg(), i.src1, i.src2, buffer),
        .fmin_d => |i| try emitFminD(i.dst.toReg(), i.src1, i.src2, buffer),
        .frintz_s => |i| try emitFrintzS(i.dst.toReg(), i.src, buffer),
        .frintz_d => |i| try emitFrintzD(i.dst.toReg(), i.src, buffer),
        .frintp_s => |i| try emitFrintpS(i.dst.toReg(), i.src, buffer),
        .frintp_d => |i| try emitFrintpD(i.dst.toReg(), i.src, buffer),
        .frintm_s => |i| try emitFrintmS(i.dst.toReg(), i.src, buffer),
        .frintm_d => |i| try emitFrintmD(i.dst.toReg(), i.src, buffer),
        .frinta_s => |i| try emitFrintaS(i.dst.toReg(), i.src, buffer),
        .frinta_d => |i| try emitFrintaD(i.dst.toReg(), i.src, buffer),
        .fmadd_s => |i| try emitFmaddS(i.dst.toReg(), i.src_n, i.src_m, i.src_a, buffer),
        .fmadd_d => |i| try emitFmaddD(i.dst.toReg(), i.src_n, i.src_m, i.src_a, buffer),
        .fmsub_s => |i| try emitFmsubS(i.dst.toReg(), i.src_n, i.src_m, i.src_a, buffer),
        .fmsub_d => |i| try emitFmsubD(i.dst.toReg(), i.src_n, i.src_m, i.src_a, buffer),
        .fnmadd_s => |i| try emitFnmaddS(i.dst.toReg(), i.src_n, i.src_m, i.src_a, buffer),
        .fnmadd_d => |i| try emitFnmaddD(i.dst.toReg(), i.src_n, i.src_m, i.src_a, buffer),
        .fnmsub_s => |i| try emitFnmsubS(i.dst.toReg(), i.src_n, i.src_m, i.src_a, buffer),
        .fnmsub_d => |i| try emitFnmsubD(i.dst.toReg(), i.src_n, i.src_m, i.src_a, buffer),
        .vec_add => |i| try emitVecAdd(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .vec_sub => |i| try emitVecSub(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .vec_mul => |i| try emitVecMul(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .vec_cmeq => |i| try emitVecCmeq(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .vec_cmgt => |i| try emitVecCmgt(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .vec_cmge => |i| try emitVecCmge(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .vec_and => |i| try emitVecAnd(i.dst.toReg(), i.src1, i.src2, buffer),
        .vec_orr => |i| try emitVecOrr(i.dst.toReg(), i.src1, i.src2, buffer),
        .vec_eor => |i| try emitVecEor(i.dst.toReg(), i.src1, i.src2, buffer),
        .vec_fadd => |i| try emitVecFadd(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .vec_fsub => |i| try emitVecFsub(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .vec_fmul => |i| try emitVecFmul(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .vec_fdiv => |i| try emitVecFdiv(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .addv => |i| try emitAddv(i.dst.toReg(), i.src, i.size, buffer),
        .sminv => |i| try emitSminv(i.dst.toReg(), i.src, i.size, buffer),
        .smaxv => |i| try emitSmaxv(i.dst.toReg(), i.src, i.size, buffer),
        .uminv => |i| try emitUminv(i.dst.toReg(), i.src, i.size, buffer),
        .umaxv => |i| try emitUmaxv(i.dst.toReg(), i.src, i.size, buffer),
        .zip1 => |i| try emitZip1(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .zip2 => |i| try emitZip2(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .uzp1 => |i| try emitUzp1(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .uzp2 => |i| try emitUzp2(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .trn1 => |i| try emitTrn1(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .trn2 => |i| try emitTrn2(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .ld1 => |i| try emitLd1(i.dst.toReg(), i.addr, i.size, buffer),
        .st1 => |i| try emitSt1(i.src, i.addr, i.size, buffer),
        .ins => |i| try emitIns(i.dst.toReg(), i.src, i.index, i.size, buffer),
        .ext => |i| try emitExt(i.dst.toReg(), i.src1, i.src2, i.imm, buffer),
        .dup_elem => |i| try emitDupElem(i.dst.toReg(), i.src, i.index, i.size, buffer),
        .sxtl => |i| try emitSxtl(i.dst.toReg(), i.src, i.size, buffer),
        .uxtl => |i| try emitUxtl(i.dst.toReg(), i.src, i.size, buffer),
        .saddl => |i| try emitSaddl(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
        .uaddl => |i| try emitUaddl(i.dst.toReg(), i.src1, i.src2, i.size, buffer),
    }
}

/// Get hardware register encoding.
fn hwEnc(reg: Reg) u5 {
    if (reg.isVirtual()) {
        // For testing - map virtual regs to physical
        return @intCast(reg.toVReg().index() % 31);
    } else {
        return @intCast(reg.toPReg().hwEnc() & 0x1F);
    }
}

/// Get sf bit for 64-bit operands.
fn sf(size: OperandSize) u1 {
    return switch (size) {
        .size32 => 0,
        .size64 => 1,
    };
}

/// MOV Xd, Xn (implemented as ORR Xd, XZR, Xn)
fn emitMovRR(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rm = hwEnc(src);

    // ORR Xd, XZR, Xn: sf|01010100|shift|0|Rm|imm6|11111|Rd
    // Using logical shift left by 0
    const insn: u32 = (sf_bit << 31) |
        (0b01010100 << 21) |
        (@as(u32, rm) << 16) |
        (0b11111 << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MOV Xd, #imm (using MOVZ for low 16 bits)
fn emitMovImm(dst: Reg, imm: u64, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const imm16: u16 = @truncate(imm);

    // MOVZ Xd, #imm: sf|10100101|hw|imm16|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b10100101 << 23) |
        (@as(u32, imm16) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MOVZ - Move wide with zero
/// Encoding: sf|opc|100101|hw|imm16|Rd
/// opc=10 for MOVZ, hw = shift / 16
fn emitMovz(dst: Reg, imm: u16, shift: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const hw: u2 = @intCast(shift / 16);

    // MOVZ: sf|10|100101|hw|imm16|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b10100101 << 23) |
        (@as(u32, hw) << 21) |
        (@as(u32, imm) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MOVK - Move wide with keep
/// Encoding: sf|opc|100101|hw|imm16|Rd
/// opc=11 for MOVK, hw = shift / 16
fn emitMovk(dst: Reg, imm: u16, shift: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const hw: u2 = @intCast(shift / 16);

    // MOVK: sf|11|100101|hw|imm16|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11100101 << 23) |
        (@as(u32, hw) << 21) |
        (@as(u32, imm) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MOVN - Move wide with NOT
/// Encoding: sf|opc|100101|hw|imm16|Rd
/// opc=00 for MOVN, hw = shift / 16
fn emitMovn(dst: Reg, imm: u16, shift: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const hw: u2 = @intCast(shift / 16);

    // MOVN: sf|00|100101|hw|imm16|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b00100101 << 23) |
        (@as(u32, hw) << 21) |
        (@as(u32, imm) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ADD Xd, Xn, Xm
fn emitAddRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // ADD: sf|0|0|01011|shift|0|Rm|imm6|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b01011 << 24) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ADD Xd, Xn, #imm
fn emitAddImm(dst: Reg, src: Reg, imm: u16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const imm12: u12 = @truncate(imm);

    // ADD imm: sf|0|0|10001|shift|imm12|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b10001 << 24) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ADD Xd, Xn, Xm, shift_op #shift_amt
/// ADD (shifted register) instruction
fn emitAddShifted(dst: Reg, src1: Reg, src2: Reg, shift_op: root.aarch64_inst.ShiftOp, shift_amt: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const shift: u32 = @intFromEnum(shift_op);
    const imm6: u32 = @intCast(shift_amt);

    // ADD (shifted register): sf|0|0|01011|shift|0|Rm|imm6|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b01011 << 24) |
        (shift << 22) |
        (@as(u32, rm) << 16) |
        (imm6 << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ADD Xd, Xn, Wm, extend_op
/// ADD (extended register) instruction
fn emitAddExtended(dst: Reg, src1: Reg, src2: Reg, extend_op: root.aarch64_inst.ExtendOp, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const option: u32 = @intFromEnum(extend_op);
    const imm3: u32 = 0; // shift amount, typically 0 for add with extend

    // ADD (extended register): sf|0|0|01011|00|1|Rm|option|imm3|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b01011 << 24) |
        (0b00 << 22) |
        (1 << 21) |
        (@as(u32, rm) << 16) |
        (option << 13) |
        (imm3 << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SUB Xd, Xn, Xm
fn emitSubRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // SUB: sf|1|0|01011|shift|0|Rm|imm6|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (1 << 30) |
        (0b01011 << 24) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SUB Xd, Xn, #imm
fn emitSubImm(dst: Reg, src: Reg, imm: u16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const imm12: u12 = @truncate(imm);

    // SUB imm: sf|1|0|10001|shift|imm12|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (1 << 30) |
        (0b10001 << 24) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ADDS Xd, Xn, Xm (add and set flags)
fn emitAddsRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // ADDS: sf|0|1|01011|shift|0|Rm|imm6|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b01 << 29) |
        (0b01011 << 24) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ADDS Xd, Xn, #imm (add immediate and set flags)
fn emitAddsImm(dst: Reg, src: Reg, imm: u16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const imm12: u12 = @truncate(imm);

    // ADDS imm: sf|0|1|10001|shift|imm12|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b01 << 29) |
        (0b10001 << 24) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SUBS Xd, Xn, Xm (subtract and set flags)
fn emitSubsRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // SUBS: sf|1|1|01011|shift|0|Rm|imm6|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11 << 29) |
        (0b01011 << 24) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SUBS Xd, Xn, #imm (subtract immediate and set flags)
fn emitSubsImm(dst: Reg, src: Reg, imm: u16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const imm12: u12 = @truncate(imm);

    // SUBS imm: sf|1|1|10001|shift|imm12|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11 << 29) |
        (0b10001 << 24) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MUL Xd, Xn, Xm (alias for MADD Xd, Xn, Xm, XZR)
fn emitMulRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra: u5 = 31; // XZR

    // MADD: sf|0|0|11011|000|Rm|0|Ra|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11011000 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MADD Xd, Xn, Xm, Xa
fn emitMadd(dst: Reg, src1: Reg, src2: Reg, addend: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra = hwEnc(addend);

    // MADD: sf|0|0|11011|000|Rm|0|Ra|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11011000 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MSUB Xd, Xn, Xm, Xa
fn emitMsub(dst: Reg, src1: Reg, src2: Reg, subtrahend: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra = hwEnc(subtrahend);

    // MSUB: sf|0|0|11011|000|Rm|1|Ra|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11011000 << 21) |
        (@as(u32, rm) << 16) |
        (1 << 15) | // o0 bit
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SMULH Xd, Xn, Xm (signed multiply high)
fn emitSmulh(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra: u5 = 31; // Must be 31

    // SMULH: 1|0|0|11011|010|Rm|0|11111|Rn|Rd
    const insn: u32 = (1 << 31) |
        (0b11011010 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UMULH Xd, Xn, Xm (unsigned multiply high)
fn emitUmulh(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra: u5 = 31; // Must be 31

    // UMULH: 1|0|0|11011|110|Rm|0|11111|Rn|Rd
    const insn: u32 = (1 << 31) |
        (0b11011110 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SMULL Xd, Wn, Wm (signed multiply long 32x32→64)
fn emitSmull(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra: u5 = 31; // XZR

    // SMULL (alias for SMADDL with Ra=31): 1|0|0|11011|001|Rm|0|11111|Rn|Rd
    const insn: u32 = (1 << 31) |
        (0b11011001 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UMULL Xd, Wn, Wm (unsigned multiply long 32x32→64)
fn emitUmull(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const ra: u5 = 31; // XZR

    // UMULL (alias for UMADDL with Ra=31): 1|0|0|11011|101|Rm|0|11111|Rn|Rd
    const insn: u32 = (1 << 31) |
        (0b11011101 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SDIV Xd, Xn, Xm (signed divide)
fn emitSdiv(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // SDIV: sf|0|0|11010110|Rm|00001|1|Rn|Rd
    // Encoding: sf|0|0|11010110|Rm[20:16]|00001[15:11]|1[10]|Rn[9:5]|Rd[4:0]
    // Note: bits 15-11 are 00001 for both SDIV and UDIV; bit 10 distinguishes them
    const insn: u32 = (sf_bit << 31) |
        (0b11010110 << 21) |
        (@as(u32, rm) << 16) |
        (0b00001 << 11) |
        (1 << 10) | // bit 10 = 1 for SDIV, 0 for UDIV
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UDIV Xd, Xn, Xm (unsigned divide)
fn emitUdiv(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // UDIV: sf|0|0|11010110|Rm|00001|0|Rn|Rd
    // Encoding: sf|0|0|11010110|Rm[20:16]|00001[15:11]|0[10]|Rn[9:5]|Rd[4:0]
    // Note: bits 15-11 are 00001 for both SDIV and UDIV; bit 10 distinguishes them
    const insn: u32 = (sf_bit << 31) |
        (0b11010110 << 21) |
        (@as(u32, rm) << 16) |
        (0b00001 << 11) |
        (0 << 10) | // bit 10 = 0 for UDIV, 1 for SDIV
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LSL Xd, Xn, Xm (logical shift left, variable)
fn emitLslRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // LSLV (LSL variable): sf|0|0|11010110|Rm|001000|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11010110 << 21) |
        (@as(u32, rm) << 16) |
        (0b001000 << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LSL Xd, Xn, #imm (logical shift left, immediate)
fn emitLslImm(dst: Reg, src: Reg, imm: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const datasize: u8 = if (size == .size64) 64 else 32;

    // LSL is an alias for UBFM (unsigned bitfield move)
    // LSL Xd, Xn, #shift == UBFM Xd, Xn, #(-shift MOD datasize), #(datasize-1-shift)
    const immr: u8 = @truncate((datasize - imm) % datasize);
    const imms: u8 = datasize - 1 - imm;
    const n: u1 = if (size == .size64) 1 else 0;

    // UBFM: sf|10|100110|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b10100110 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, immr) << 16) |
        (@as(u32, imms) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LSR Xd, Xn, Xm (logical shift right, variable)
fn emitLsrRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // LSRV (LSR variable): sf|0|0|11010110|Rm|001001|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11010110 << 21) |
        (@as(u32, rm) << 16) |
        (0b001001 << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LSR Xd, Xn, #imm (logical shift right, immediate)
fn emitLsrImm(dst: Reg, src: Reg, imm: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const datasize: u8 = if (size == .size64) 64 else 32;
    const n: u1 = if (size == .size64) 1 else 0;

    // LSR is an alias for UBFM: LSR Xd, Xn, #shift == UBFM Xd, Xn, #shift, #(datasize-1)
    const immr: u8 = imm;
    const imms: u8 = datasize - 1;

    // UBFM: sf|10|100110|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b10100110 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, immr) << 16) |
        (@as(u32, imms) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ASR Xd, Xn, Xm (arithmetic shift right, variable)
fn emitAsrRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // ASRV (ASR variable): sf|0|0|11010110|Rm|001010|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11010110 << 21) |
        (@as(u32, rm) << 16) |
        (0b001010 << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ASR Xd, Xn, #imm (arithmetic shift right, immediate)
fn emitAsrImm(dst: Reg, src: Reg, imm: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const datasize: u8 = if (size == .size64) 64 else 32;
    const n: u1 = if (size == .size64) 1 else 0;

    // ASR is an alias for SBFM: ASR Xd, Xn, #shift == SBFM Xd, Xn, #shift, #(datasize-1)
    const immr: u8 = imm;
    const imms: u8 = datasize - 1;

    // SBFM: sf|00|100110|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b00100110 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, immr) << 16) |
        (@as(u32, imms) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ROR Xd, Xn, Xm (rotate right, variable)
fn emitRorRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // RORV (ROR variable): sf|0|0|11010110|Rm|001011|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11010110 << 21) |
        (@as(u32, rm) << 16) |
        (0b001011 << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ROR Xd, Xn, #imm (rotate right, immediate)
fn emitRorImm(dst: Reg, src: Reg, imm: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const rs = hwEnc(src); // Source register used twice

    // ROR is an alias for EXTR: ROR Xd, Xn, #shift == EXTR Xd, Xn, Xn, #shift
    const n: u1 = if (size == .size64) 1 else 0;

    // EXTR: sf|00|100111|N|0|Rm|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b00100111 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, rs) << 16) |
        (@as(u32, imm) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// AND Xd, Xn, Xm (bitwise AND register)
fn emitAndRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // AND (shifted register): sf|00|01010|shift|0|Rm|imm6|Rn|Rd
    // Using shift=00 (LSL), imm6=0 (no shift)
    const insn: u32 = (sf_bit << 31) |
        (0b00001010 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// AND Xd, Xn, #imm (bitwise AND immediate)
fn emitAndImm(dst: Reg, src: Reg, imm_logic: root.aarch64_inst.ImmLogic, buffer: *buffer_mod.MachBuffer) !void {
    const size = imm_logic.size;
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const n: u1 = if (imm_logic.n) 1 else 0;

    // AND (immediate): sf|00|100100|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b00100100 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, imm_logic.r) << 16) |
        (@as(u32, imm_logic.s) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ORR Xd, Xn, Xm (bitwise OR register)
fn emitOrrRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // ORR (shifted register): sf|01|01010|shift|0|Rm|imm6|Rn|Rd
    // Using shift=00 (LSL), imm6=0 (no shift)
    const insn: u32 = (sf_bit << 31) |
        (0b01001010 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ORR Xd, Xn, #imm (bitwise OR immediate)
fn emitOrrImm(dst: Reg, src: Reg, imm_logic: root.aarch64_inst.ImmLogic, buffer: *buffer_mod.MachBuffer) !void {
    const size = imm_logic.size;
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const n: u1 = if (imm_logic.n) 1 else 0;

    // ORR (immediate): sf|01|100100|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b01100100 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, imm_logic.r) << 16) |
        (@as(u32, imm_logic.s) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// EOR Xd, Xn, Xm (bitwise XOR register)
fn emitEorRR(dst: Reg, src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // EOR (shifted register): sf|10|01010|shift|0|Rm|imm6|Rn|Rd
    // Using shift=00 (LSL), imm6=0 (no shift)
    const insn: u32 = (sf_bit << 31) |
        (0b10001010 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// EOR Xd, Xn, #imm (bitwise XOR immediate)
fn emitEorImm(dst: Reg, src: Reg, imm_logic: root.aarch64_inst.ImmLogic, buffer: *buffer_mod.MachBuffer) !void {
    const size = imm_logic.size;
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const n: u1 = if (imm_logic.n) 1 else 0;

    // EOR (immediate): sf|10|100100|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b10100100 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, imm_logic.r) << 16) |
        (@as(u32, imm_logic.s) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// MVN Xd, Xm (bitwise NOT - implemented as ORN Xd, XZR, Xm)
fn emitMvnRR(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rm = hwEnc(src);
    const rn: u5 = 31; // XZR

    // ORN (shifted register): sf|01|01010|shift|1|Rm|imm6|Rn|Rd
    // MVN Xd, Xm == ORN Xd, XZR, Xm with shift=00 (LSL), imm6=0
    // ORN has bit 21 set to distinguish from ORR
    const insn: u32 = (sf_bit << 31) |
        (0b01001010001 << 21) | // ORN opcode (note the extra 1 bit at the end for NOT variant)
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// NEG Xd, Xm (negate - implemented as SUB Xd, XZR, Xm)
fn emitNeg(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    // NEG is an alias for SUB with XZR as first source
    const xzr = if (size == .size64) root.reg.PReg.xzr else root.reg.PReg.wzr;
    const src1 = Reg.fromPReg(xzr);
    try emitSubRR(dst, src1, src, size, buffer);
}

/// NGC Xd, Xm (negate with carry - implemented as SBC Xd, XZR, Xm)
fn emitNgc(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rm = hwEnc(src);
    const rn: u5 = 31; // XZR

    // SBC (subtract with carry): sf|1|0|11010000|Rm|000000|Rn|Rd
    // NGC Xd, Xm == SBC Xd, XZR, Xm
    const insn: u32 = (sf_bit << 31) |
        (0b1011010000 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CMP Xn, Xm (compare register with register)
/// Alias for SUBS XZR, Xn, Xm
fn emitCmpRR(src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    // CMP is just SUBS with XZR as destination
    const xzr = if (size == .size64) root.reg.PReg.xzr else root.reg.PReg.wzr;
    const dst = Reg.fromPReg(xzr);
    try emitSubsRR(dst, src1, src2, size, buffer);
}

/// CMP Xn, #imm (compare register with immediate)
/// Alias for SUBS XZR, Xn, #imm
fn emitCmpImm(src: Reg, imm: u16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    // CMP is just SUBS with XZR as destination
    const xzr = if (size == .size64) root.reg.PReg.xzr else root.reg.PReg.wzr;
    const dst = Reg.fromPReg(xzr);
    try emitSubsImm(dst, src, imm, size, buffer);
}

/// CMN Xn, Xm (compare negative)
/// Alias for ADDS XZR, Xn, Xm
fn emitCmnRR(src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    // CMN is just ADDS with XZR as destination
    const xzr = if (size == .size64) root.reg.PReg.xzr else root.reg.PReg.wzr;
    const dst = Reg.fromPReg(xzr);
    try emitAddsRR(dst, src1, src2, size, buffer);
}

/// CMN Xn, #imm (compare negative with immediate)
/// Alias for ADDS XZR, Xn, #imm
fn emitCmnImm(src: Reg, imm: u16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    // CMN is just ADDS with XZR as destination
    const xzr = if (size == .size64) root.reg.PReg.xzr else root.reg.PReg.wzr;
    const dst = Reg.fromPReg(xzr);
    try emitAddsImm(dst, src, imm, size, buffer);
}

/// TST Xn, Xm (test bits)
/// Alias for ANDS XZR, Xn, Xm
fn emitTstRR(src1: Reg, src2: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd: u5 = 31; // XZR
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // ANDS (shifted register): sf|11|01010|shift|0|Rm|imm6|Rn|Rd
    // Using shift=00 (LSL), imm6=0 (no shift)
    const insn: u32 = (sf_bit << 31) |
        (0b11001010 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// TST Xn, #imm (test bits with immediate)
/// Alias for ANDS XZR, Xn, #imm
fn emitTstImm(src: Reg, imm_logic: root.aarch64_inst.ImmLogic, buffer: *buffer_mod.MachBuffer) !void {
    const size = imm_logic.size;
    const sf_bit: u32 = @intCast(sf(size));
    const rd: u5 = 31; // XZR
    const rn = hwEnc(src);
    const n: u1 = if (imm_logic.n) 1 else 0;

    // ANDS (immediate): sf|11|100100|N|immr|imms|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11100100 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, imm_logic.r) << 16) |
        (@as(u32, imm_logic.s) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CLZ Xd, Xn (count leading zeros)
fn emitClz(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    // CLZ: sf|1|S|11010110|opcode2|opcode|Rn|Rd
    // CLZ: sf|1|0|11010110|00000|00100|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (1 << 30) |
        (0b11010110 << 21) |
        (0b00000 << 16) | // opcode2
        (0b00100 << 10) | // opcode
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CLS Xd, Xn (count leading sign bits)
fn emitCls(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    // CLS: sf|1|S|11010110|opcode2|opcode|Rn|Rd
    // CLS: sf|1|0|11010110|00000|00101|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (1 << 30) |
        (0b11010110 << 21) |
        (0b00000 << 16) | // opcode2
        (0b00101 << 10) | // opcode
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// RBIT Xd, Xn (reverse bits)
fn emitRbit(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    // RBIT: sf|1|S|11010110|opcode2|opcode|Rn|Rd
    // RBIT: sf|1|0|11010110|00000|00000|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (1 << 30) |
        (0b11010110 << 21) |
        (0b00000 << 16) | // opcode2
        (0b00000 << 10) | // opcode
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CSEL Xd, Xn, Xm, cond (conditional select)
/// Encoding: sf|0|0|11010100|Rm|cond|00|Rn|Rd
fn emitCsel(dst: Reg, src1: Reg, src2: Reg, cond: CondCode, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const cond_bits: u32 = @intCast(@intFromEnum(cond));

    // CSEL: sf|0|0|11010100|Rm|cond|00|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11010100 << 21) |
        (@as(u32, rm) << 16) |
        (cond_bits << 12) |
        (0b00 << 10) | // op=00 for CSEL
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CSINC Xd, Xn, Xm, cond (conditional select increment)
/// Encoding: sf|0|0|11010100|Rm|cond|01|Rn|Rd
fn emitCsinc(dst: Reg, src1: Reg, src2: Reg, cond: CondCode, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const cond_bits: u32 = @intCast(@intFromEnum(cond));

    // CSINC: sf|0|0|11010100|Rm|cond|01|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (0b11010100 << 21) |
        (@as(u32, rm) << 16) |
        (cond_bits << 12) |
        (0b01 << 10) | // op=01 for CSINC
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CSINV Xd, Xn, Xm, cond (conditional select invert)
/// Encoding: sf|1|0|11010100|Rm|cond|00|Rn|Rd
fn emitCsinv(dst: Reg, src1: Reg, src2: Reg, cond: CondCode, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const cond_bits: u32 = @intCast(@intFromEnum(cond));

    // CSINV: sf|1|0|11010100|Rm|cond|00|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (1 << 30) | // bit 30=1 for CSINV
        (0b11010100 << 21) |
        (@as(u32, rm) << 16) |
        (cond_bits << 12) |
        (0b00 << 10) | // op2=00 for CSINV
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CSNEG Xd, Xn, Xm, cond (conditional select negate)
/// Encoding: sf|1|0|11010100|Rm|cond|01|Rn|Rd
fn emitCsneg(dst: Reg, src1: Reg, src2: Reg, cond: CondCode, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const cond_bits: u32 = @intCast(@intFromEnum(cond));

    // CSNEG: sf|1|0|11010100|Rm|cond|01|Rn|Rd
    const insn: u32 = (sf_bit << 31) |
        (1 << 30) | // bit 30=1 for CSNEG
        (0b11010100 << 21) |
        (@as(u32, rm) << 16) |
        (cond_bits << 12) |
        (0b01 << 10) | // op2=01 for CSNEG
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SXTB Wd/Xd, Wn (sign extend byte)
/// Sign extends lowest 8 bits to 32-bit or 64-bit destination.
/// Implemented as SBFM Wd, Wn, #0, #7 (32-bit) or SBFM Xd, Xn, #0, #7 (64-bit)
fn emitSxtb(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const n: u1 = if (size == .size64) 1 else 0;

    // SXTB is an alias for SBFM: SXTB Wd, Wn == SBFM Wd, Wn, #0, #7
    // SBFM: sf|00|100110|N|immr|imms|Rn|Rd
    const immr: u8 = 0; // Extract from bit 0
    const imms: u8 = 7; // Extract 8 bits (0-7)

    const insn: u32 = (sf_bit << 31) |
        (0b00100110 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, immr) << 16) |
        (@as(u32, imms) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SXTH Wd/Xd, Wn (sign extend halfword)
/// Sign extends lowest 16 bits to 32-bit or 64-bit destination.
/// Implemented as SBFM Wd, Wn, #0, #15 (32-bit) or SBFM Xd, Xn, #0, #15 (64-bit)
fn emitSxth(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const n: u1 = if (size == .size64) 1 else 0;

    // SXTH is an alias for SBFM: SXTH Wd, Wn == SBFM Wd, Wn, #0, #15
    // SBFM: sf|00|100110|N|immr|imms|Rn|Rd
    const immr: u8 = 0; // Extract from bit 0
    const imms: u8 = 15; // Extract 16 bits (0-15)

    const insn: u32 = (sf_bit << 31) |
        (0b00100110 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, immr) << 16) |
        (@as(u32, imms) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SXTW Xd, Wn (sign extend word)
/// Sign extends lowest 32 bits to 64-bit destination.
/// Implemented as SBFM Xd, Xn, #0, #31
fn emitSxtw(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    // SXTW is an alias for SBFM: SXTW Xd, Wn == SBFM Xd, Xn, #0, #31
    // SBFM: sf|00|100110|N|immr|imms|Rn|Rd
    // For SXTW: sf=1 (64-bit), N=1
    const sf_bit: u32 = 1;
    const n: u1 = 1;
    const immr: u8 = 0; // Extract from bit 0
    const imms: u8 = 31; // Extract 32 bits (0-31)

    const insn: u32 = (sf_bit << 31) |
        (0b00100110 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, immr) << 16) |
        (@as(u32, imms) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UXTB Wd/Xd, Wn (zero extend byte)
/// Zero extends lowest 8 bits to 32-bit or 64-bit destination.
/// Implemented as UBFM Wd, Wn, #0, #7 (32-bit) or UBFM Xd, Xn, #0, #7 (64-bit)
fn emitUxtb(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const n: u1 = if (size == .size64) 1 else 0;

    // UXTB is an alias for UBFM: UXTB Wd, Wn == UBFM Wd, Wn, #0, #7
    // UBFM: sf|10|100110|N|immr|imms|Rn|Rd
    const immr: u8 = 0; // Extract from bit 0
    const imms: u8 = 7; // Extract 8 bits (0-7)

    const insn: u32 = (sf_bit << 31) |
        (0b10100110 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, immr) << 16) |
        (@as(u32, imms) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UXTH Wd/Xd, Wn (zero extend halfword)
/// Zero extends lowest 16 bits to 32-bit or 64-bit destination.
/// Implemented as UBFM Wd, Wn, #0, #15 (32-bit) or UBFM Xd, Xn, #0, #15 (64-bit)
fn emitUxth(dst: Reg, src: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const n: u1 = if (size == .size64) 1 else 0;

    // UXTH is an alias for UBFM: UXTH Wd, Wn == UBFM Wd, Wn, #0, #15
    // UBFM: sf|10|100110|N|immr|imms|Rn|Rd
    const immr: u8 = 0; // Extract from bit 0
    const imms: u8 = 15; // Extract 16 bits (0-15)

    const insn: u32 = (sf_bit << 31) |
        (0b10100110 << 23) |
        (@as(u32, n) << 22) |
        (@as(u32, immr) << 16) |
        (@as(u32, imms) << 10) |
        (@as(u32, rn) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}
/// LDR Xt, [Xn, #offset]
fn emitLdr(dst: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    const imm9: u9 = @truncate(@as(u16, @bitCast(offset)));

    // LDR (immediate): sf|11|111|0|00|01|imm9|0|Rn|Rt
    const insn: u32 = (sf_bit << 31) |
        (0b11111000010 << 20) |
        (@as(u32, imm9) << 12) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STR Xt, [Xn, #offset]
fn emitStr(src: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src);
    const rn = hwEnc(base);
    const imm9: u9 = @truncate(@as(u16, @bitCast(offset)));

    // STR (immediate): sf|11|111|0|00|00|imm9|0|Rn|Rt
    const insn: u32 = (sf_bit << 31) |
        (0b11111000000 << 20) |
        (@as(u32, imm9) << 12) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDR Xt, [Xn, Xm] (register offset, no shift)
fn emitLdrReg(dst: Reg, base: Reg, offset: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    const rm = hwEnc(offset);

    // LDR (register): sf|111|0|00|01|Rm|011|0|10|Rn|Rt
    // option=011 (LSL/reserved), S=0 (no scale)
    const insn: u32 = (sf_bit << 31) |
        (0b11100001 << 21) |
        (@as(u32, rm) << 16) |
        (0b011010 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDR Xt, [Xn, Wm, extend] (extended register offset)
fn emitLdrExt(dst: Reg, base: Reg, offset: Reg, extend: Inst.ExtendOp, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    const rm = hwEnc(offset);
    const option: u3 = @intFromEnum(extend);

    // LDR (register, extended): sf|111|0|00|01|Rm|option|S|10|Rn|Rt
    // S=0 (no scale)
    const insn: u32 = (sf_bit << 31) |
        (0b11100001 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, option) << 13) |
        (0b010 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDR Xt, [Xn, Xm, shift_op #shift_amt] (shifted register offset)
///
/// Implements the "Load Register (register offset)" instruction format from the
/// ARM Architecture Reference Manual (ARM DDI 0487).
///
/// Encoding: sf|111|V|00|opc|1|Rm|option|S|10|Rn|Rt
/// - sf: 0=32-bit (W), 1=64-bit (X)
/// - V: 0 for GPR
/// - opc: 01 for LDR
/// - Rm: Offset register (bits 20-16)
/// - option: 011 for LSL (bits 15-13)
/// - S: Scale flag (bit 12): 0=no scale, 1=scale by log2(access_size)
/// - Rn: Base register (bits 9-5)
/// - Rt: Destination register (bits 4-0)
///
/// Note: ARM64 load/store register offset only supports LSL shift operation.
/// LSR and ASR are NOT valid for load/store addressing modes (ARM ARM C3.3.8).
/// Attempting to use them will cause a runtime panic.
///
/// Example: LDR X0, [X1, X2, LSL #3] loads from address (X1 + (X2 << 3))
fn emitLdrShifted(dst: Reg, base: Reg, offset: Reg, shift_op: Inst.ShiftOp, shift_amt: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    // Validate that only LSL is used for load/store addressing
    if (shift_op != .lsl) {
        @panic("ARM64 load/store register offset only supports LSL shift operation");
    }

    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    const rm = hwEnc(offset);
    const s_bit: u1 = if (shift_amt > 0) 1 else 0;

    // LDR (register, shifted): sf|111|0|00|01|Rm|011|S|10|Rn|Rt
    // option=011 (LSL), S bit indicates whether to scale by transfer size
    const insn: u32 = (sf_bit << 31) |
        (0b11100001 << 21) |
        (@as(u32, rm) << 16) |
        (0b011 << 13) |
        (@as(u32, s_bit) << 12) |
        (0b10 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STR Xt, [Xn, Xm] (register offset, no shift)
fn emitStrReg(src: Reg, base: Reg, offset: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src);
    const rn = hwEnc(base);
    const rm = hwEnc(offset);

    // STR (register): sf|111|0|00|00|Rm|011|0|10|Rn|Rt
    // option=011 (LSL/reserved), S=0 (no scale)
    const insn: u32 = (sf_bit << 31) |
        (0b11100000 << 21) |
        (@as(u32, rm) << 16) |
        (0b011010 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STR Xt, [Xn, Wm, extend] (extended register offset)
fn emitStrExt(src: Reg, base: Reg, offset: Reg, extend: Inst.ExtendOp, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src);
    const rn = hwEnc(base);
    const rm = hwEnc(offset);
    const option: u3 = @intFromEnum(extend);

    // STR (register, extended): sf|111|0|00|00|Rm|option|S|10|Rn|Rt
    // S=0 (no scale)
    const insn: u32 = (sf_bit << 31) |
        (0b11100000 << 21) |
        (@as(u32, rm) << 16) |
        (@as(u32, option) << 13) |
        (0b010 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STR Xt, [Xn, Xm, shift_op #shift_amt] (shifted register offset)
///
/// Implements the "Store Register (register offset)" instruction format from the
/// ARM Architecture Reference Manual (ARM DDI 0487).
///
/// Encoding: sf|111|V|00|opc|1|Rm|option|S|10|Rn|Rt
/// - sf: 0=32-bit (W), 1=64-bit (X)
/// - V: 0 for GPR
/// - opc: 00 for STR
/// - Rm: Offset register (bits 20-16)
/// - option: 011 for LSL (bits 15-13)
/// - S: Scale flag (bit 12): 0=no scale, 1=scale by log2(access_size)
/// - Rn: Base register (bits 9-5)
/// - Rt: Source register (bits 4-0)
///
/// Note: ARM64 load/store register offset only supports LSL shift operation.
/// LSR and ASR are NOT valid for load/store addressing modes (ARM ARM C3.3.8).
/// Attempting to use them will cause a runtime panic.
///
/// Example: STR X0, [X1, X2, LSL #3] stores to address (X1 + (X2 << 3))
fn emitStrShifted(src: Reg, base: Reg, offset: Reg, shift_op: Inst.ShiftOp, shift_amt: u8, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    // Validate that only LSL is used for load/store addressing
    if (shift_op != .lsl) {
        @panic("ARM64 load/store register offset only supports LSL shift operation");
    }

    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src);
    const rn = hwEnc(base);
    const rm = hwEnc(offset);
    const s_bit: u1 = if (shift_amt > 0) 1 else 0;

    // STR (register, shifted): sf|111|0|00|00|Rm|011|S|10|Rn|Rt
    // option=011 (LSL), S bit indicates whether to scale by transfer size
    const insn: u32 = (sf_bit << 31) |
        (0b11100000 << 21) |
        (@as(u32, rm) << 16) |
        (0b011 << 13) |
        (@as(u32, s_bit) << 12) |
        (0b10 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDRB Wt, [Xn, #offset] - Load byte (unsigned, zero-extend)
fn emitLdrb(dst: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    _ = size; // Byte loads are always to W registers, size affects dest reg type only
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    const imm12: u12 = @truncate(@as(u16, @bitCast(offset)));

    // LDRB (immediate, unsigned offset): size|111|V|00|opc|imm12|Rn|Rt
    // size=00 (8-bit), V=0 (GPR), opc=01 (unsigned load)
    const insn: u32 = (0b00 << 30) | // size
        (0b111 << 27) |
        (0b0 << 26) | // V
        (0b00 << 24) |
        (0b01 << 22) | // opc
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDRH Wt, [Xn, #offset] - Load halfword (unsigned, zero-extend)
fn emitLdrh(dst: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    _ = size; // Halfword loads are always to W registers, size affects dest reg type only
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    // Offset is scaled by 2 for halfword
    const imm12: u12 = @truncate(@as(u16, @bitCast(offset)) >> 1);

    // LDRH (immediate, unsigned offset): size|111|V|00|opc|imm12|Rn|Rt
    // size=01 (16-bit), V=0 (GPR), opc=01 (unsigned load)
    const insn: u32 = (0b01 << 30) | // size
        (0b111 << 27) |
        (0b0 << 26) | // V
        (0b00 << 24) |
        (0b01 << 22) | // opc
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDRSB Wt/Xt, [Xn, #offset] - Load signed byte
fn emitLdrsb(dst: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const opc: u2 = if (size == .size64) 0b10 else 0b11; // 10=64-bit dest, 11=32-bit dest
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    const imm12: u12 = @truncate(@as(u16, @bitCast(offset)));

    // LDRSB (immediate, unsigned offset): size|111|V|00|opc|imm12|Rn|Rt
    // size=00 (8-bit), V=0 (GPR), opc=10/11 (signed, 64/32-bit dest)
    const insn: u32 = (0b00 << 30) | // size
        (0b111 << 27) |
        (0b0 << 26) | // V
        (0b00 << 24) |
        (@as(u32, opc) << 22) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDRSH Wt/Xt, [Xn, #offset] - Load signed halfword
fn emitLdrsh(dst: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const opc: u2 = if (size == .size64) 0b10 else 0b11; // 10=64-bit dest, 11=32-bit dest
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    // Offset is scaled by 2 for halfword
    const imm12: u12 = @truncate(@as(u16, @bitCast(offset)) >> 1);

    // LDRSH (immediate, unsigned offset): 01|111|0|01|opc|imm12|Rn|Rt
    // size=01 (16-bit), VR=0, opc=10/11 (signed, 64/32-bit dest)
    const insn: u32 = (0b01111001 << 22) |
        (@as(u32, opc) << 22) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDRSW Xt, [Xn, #offset] - Load signed word (32→64 bit)
fn emitLdrsw(dst: Reg, base: Reg, offset: i16, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    // Offset is scaled by 4 for word
    const imm12: u12 = @truncate(@as(u16, @bitCast(offset)) >> 2);

    // LDRSW (immediate, unsigned offset): 10|111|0|01|10|imm12|Rn|Rt
    // size=10 (32-bit), VR=0, opc=10 (signed, 64-bit dest)
    const insn: u32 = (0b10111001 << 22) |
        (0b10 << 22) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STRB Wt, [Xn, #offset] - Store byte
fn emitStrb(src: Reg, base: Reg, offset: i16, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(src);
    const rn = hwEnc(base);
    const imm12: u12 = @truncate(@as(u16, @bitCast(offset)));

    // STRB (immediate, unsigned offset): 00|111|0|01|00|imm12|Rn|Rt
    // size=00 (8-bit), VR=0, opc=00 (store)
    const insn: u32 = (0b00111001 << 22) |
        (0b00 << 22) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STRH Wt, [Xn, #offset] - Store halfword
fn emitStrh(src: Reg, base: Reg, offset: i16, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(src);
    const rn = hwEnc(base);
    // Offset is scaled by 2 for halfword
    const imm12: u12 = @truncate(@as(u16, @bitCast(offset)) >> 1);

    // STRH (immediate, unsigned offset): 01|111|0|01|00|imm12|Rn|Rt
    // size=01 (16-bit), VR=0, opc=00 (store)
    const insn: u32 = (0b01111001 << 22) |
        (0b00 << 22) |
        (@as(u32, imm12) << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STP Xt1, Xt2, [Xn, #offset]
fn emitStp(src1: Reg, src2: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src1);
    const rt2 = hwEnc(src2);
    const rn = hwEnc(base);
    // Offset is scaled by size: 8 bytes for 64-bit, 4 bytes for 32-bit
    const scale: u4 = if (size == .size64) 3 else 2; // shift by 3 (÷8) for 64-bit, 2 (÷4) for 32-bit
    const imm7: u7 = @truncate(@as(u16, @bitCast(offset)) >> scale);

    // STP: sf|10|1|0|010|0|imm7|Rt2|Rn|Rt
    const insn: u32 = (sf_bit << 31) |
        (0b1010010 << 23) |
        (@as(u32, imm7) << 15) |
        (@as(u32, rt2) << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDP Xt1, Xt2, [Xn, #offset]
fn emitLdp(dst1: Reg, dst2: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst1);
    const rt2 = hwEnc(dst2);
    const rn = hwEnc(base);
    // Offset is scaled by size: 8 bytes for 64-bit, 4 bytes for 32-bit
    const scale: u4 = if (size == .size64) 3 else 2; // shift by 3 (÷8) for 64-bit, 2 (÷4) for 32-bit
    const imm7: u7 = @truncate(@as(u16, @bitCast(offset)) >> scale);

    // LDP: sf|10|1|0|011|0|imm7|Rt2|Rn|Rt
    const insn: u32 = (sf_bit << 31) |
        (0b1010011 << 23) |
        (@as(u32, imm7) << 15) |
        (@as(u32, rt2) << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDR Xt, [Xn, #offset]! (pre-index)
/// Updates base register before memory access: base = base + offset, then load from base.
/// Encoding: sf|111|0|00|01|imm9|11|Rn|Rt
/// - sf: 0=32-bit (W), 1=64-bit (X)
/// - imm9: 9-bit signed immediate offset (-256 to +255)
/// - bits[11:10] = 11 for pre-index
/// - Rn: Base register (updated)
/// - Rt: Destination register
fn emitLdrPre(dst: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    const imm9: u9 = @truncate(@as(u16, @bitCast(offset)));

    // LDR (immediate, pre-index): sf|111|0|00|01|imm9|11|Rn|Rt
    const insn: u32 = (sf_bit << 31) |
        (0b11100001 << 21) |
        (@as(u32, imm9) << 12) |
        (0b11 << 10) | // pre-index mode
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDR Xt, [Xn], #offset (post-index)
/// Updates base register after memory access: load from base, then base = base + offset.
/// Encoding: sf|111|0|00|01|imm9|01|Rn|Rt
/// - sf: 0=32-bit (W), 1=64-bit (X)
/// - imm9: 9-bit signed immediate offset (-256 to +255)
/// - bits[11:10] = 01 for post-index
/// - Rn: Base register (updated)
/// - Rt: Destination register
fn emitLdrPost(dst: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst);
    const rn = hwEnc(base);
    const imm9: u9 = @truncate(@as(u16, @bitCast(offset)));

    // LDR (immediate, post-index): sf|111|0|00|01|imm9|01|Rn|Rt
    const insn: u32 = (sf_bit << 31) |
        (0b11100001 << 21) |
        (@as(u32, imm9) << 12) |
        (0b01 << 10) | // post-index mode
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STR Xt, [Xn, #offset]! (pre-index)
/// Updates base register before memory access: base = base + offset, then store to base.
/// Encoding: sf|111|0|00|00|imm9|11|Rn|Rt
/// - sf: 0=32-bit (W), 1=64-bit (X)
/// - imm9: 9-bit signed immediate offset (-256 to +255)
/// - bits[11:10] = 11 for pre-index
/// - Rn: Base register (updated)
/// - Rt: Source register
fn emitStrPre(src: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src);
    const rn = hwEnc(base);
    const imm9: u9 = @truncate(@as(u16, @bitCast(offset)));

    // STR (immediate, pre-index): sf|111|0|00|00|imm9|11|Rn|Rt
    const insn: u32 = (sf_bit << 31) |
        (0b11100000 << 21) |
        (@as(u32, imm9) << 12) |
        (0b11 << 10) | // pre-index mode
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STR Xt, [Xn], #offset (post-index)
/// Updates base register after memory access: store to base, then base = base + offset.
/// Encoding: sf|111|0|00|00|imm9|01|Rn|Rt
/// - sf: 0=32-bit (W), 1=64-bit (X)
/// - imm9: 9-bit signed immediate offset (-256 to +255)
/// - bits[11:10] = 01 for post-index
/// - Rn: Base register (updated)
/// - Rt: Source register
fn emitStrPost(src: Reg, base: Reg, offset: i16, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(src);
    const rn = hwEnc(base);
    const imm9: u9 = @truncate(@as(u16, @bitCast(offset)));

    // STR (immediate, post-index): sf|111|0|00|00|imm9|01|Rn|Rt
    const insn: u32 = (sf_bit << 31) |
        (0b11100000 << 21) |
        (@as(u32, imm9) << 12) |
        (0b01 << 10) | // post-index mode
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDARB Wt, [Xn] - Load-Acquire Register Byte
fn emitLdarb(dst: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);

    // LDARB: size|001000|1|L|1|Rs|1|Rt2|Rn|Rt
    // size=00 (byte), L=1 (load), Rs=11111, Rt2=11111
    // Encoding: 00|001000|1|1|1|11111|1|11111|Rn|Rt
    const insn: u32 = (0b00 << 30) | // size = byte
        (0b001000 << 24) |
        (1 << 23) | // fixed bit
        (1 << 22) | // L = load
        (1 << 21) | // o0
        (0b11111 << 16) | // Rs = 31
        (0b1111111 << 10) | // fixed bit + Rt2 = 31 (bits [15:10] = 111111)
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDARH Wt, [Xn] - Load-Acquire Register Halfword
fn emitLdarh(dst: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);

    // LDARH: size|001000|1|L|1|Rs|1|Rt2|Rn|Rt
    // size=01 (halfword), L=1 (load), Rs=11111, Rt2=11111
    const insn: u32 = (0b01 << 30) | // size = halfword
        (0b001000 << 24) |
        (1 << 23) | // fixed bit
        (1 << 22) | // L = load
        (1 << 21) | // o0
        (0b11111 << 16) | // Rs = 31
        (0b1111111 << 10) | // fixed bit + Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDAR Wt, [Xn] - Load-Acquire Register Word
fn emitLdarW(dst: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);

    // LDAR: size|001000|1|L|1|Rs|1|Rt2|Rn|Rt
    // size=10 (word), L=1 (load), Rs=11111, Rt2=11111
    const insn: u32 = (0b10 << 30) | // size = word
        (0b001000 << 24) |
        (1 << 23) | // fixed bit
        (1 << 22) | // L = load
        (1 << 21) | // o0
        (0b11111 << 16) | // Rs = 31
        (0b1111111 << 10) | // fixed bit + Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDAR Xt, [Xn] - Load-Acquire Register Doubleword
fn emitLdarX(dst: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);

    // LDAR: size|001000|1|L|1|Rs|1|Rt2|Rn|Rt
    // size=11 (doubleword), L=1 (load), Rs=11111, Rt2=11111
    const insn: u32 = (0b11 << 30) | // size = doubleword
        (0b001000 << 24) |
        (1 << 23) | // fixed bit
        (1 << 22) | // L = load
        (1 << 21) | // o0
        (0b11111 << 16) | // Rs = 31
        (0b1111111 << 10) | // fixed bit + Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STLRB Wt, [Xn] - Store-Release Register Byte
fn emitStlrb(src: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(src);
    const rn = hwEnc(base);

    // STLRB: size|001000|1|L|1|Rs|1|Rt2|Rn|Rt
    // size=00 (byte), L=0 (store), Rs=11111, Rt2=11111
    const insn: u32 = (0b00 << 30) | // size = byte
        (0b001000 << 24) |
        (1 << 23) | // fixed bit
        (0 << 22) | // L = store
        (1 << 21) | // o0
        (0b11111 << 16) | // Rs = 31
        (0b1111111 << 10) | // fixed bit + Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STLRH Wt, [Xn] - Store-Release Register Halfword
fn emitStlrh(src: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(src);
    const rn = hwEnc(base);

    // STLRH: size|001000|1|L|1|Rs|1|Rt2|Rn|Rt
    // size=01 (halfword), L=0 (store), Rs=11111, Rt2=11111
    const insn: u32 = (0b01 << 30) | // size = halfword
        (0b001000 << 24) |
        (1 << 23) | // fixed bit
        (0 << 22) | // L = store
        (1 << 21) | // o0
        (0b11111 << 16) | // Rs = 31
        (0b1111111 << 10) | // fixed bit + Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STLR Wt, [Xn] - Store-Release Register Word
fn emitStlrW(src: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(src);
    const rn = hwEnc(base);

    // STLR: size|001000|1|L|1|Rs|1|Rt2|Rn|Rt
    // size=10 (word), L=0 (store), Rs=11111, Rt2=11111
    const insn: u32 = (0b10 << 30) | // size = word
        (0b001000 << 24) |
        (1 << 23) | // fixed bit
        (0 << 22) | // L = store
        (1 << 21) | // o0
        (0b11111 << 16) | // Rs = 31
        (0b1111111 << 10) | // fixed bit + Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STLR Xt, [Xn] - Store-Release Register Doubleword
fn emitStlrX(src: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(src);
    const rn = hwEnc(base);

    // STLR: size|001000|1|L|1|Rs|1|Rt2|Rn|Rt
    // size=11 (doubleword), L=0 (store), Rs=11111, Rt2=11111
    const insn: u32 = (0b11 << 30) | // size = doubleword
        (0b001000 << 24) |
        (1 << 23) | // fixed bit
        (0 << 22) | // L = store
        (1 << 21) | // o0
        (0b11111 << 16) | // Rs = 31
        (0b1111111 << 10) | // fixed bit + Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

// === Exclusive Access Instructions ===

/// LDXR - Load Exclusive Register (32-bit)
/// Encoding: size|001000|0|1|0|Rs|0|Rt2|Rn|Rt
fn emitLdxrW(dst: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);

    const insn: u32 = (0b10 << 30) | // size = word
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (1 << 22) | // L = load
        (0 << 21) | // o0
        (0b11111 << 16) | // Rs = 31 (unpredictable)
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDXR - Load Exclusive Register (64-bit)
fn emitLdxrX(dst: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);

    const insn: u32 = (0b11 << 30) | // size = doubleword
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (1 << 22) | // L = load
        (0 << 21) | // o0
        (0b11111 << 16) | // Rs = 31 (unpredictable)
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDXRB - Load Exclusive Register Byte
fn emitLdxrb(dst: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);

    const insn: u32 = (0b00 << 30) | // size = byte
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (1 << 22) | // L = load
        (0 << 21) | // o0
        (0b11111 << 16) | // Rs = 31
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDXRH - Load Exclusive Register Halfword
fn emitLdxrh(dst: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);

    const insn: u32 = (0b01 << 30) | // size = halfword
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (1 << 22) | // L = load
        (0 << 21) | // o0
        (0b11111 << 16) | // Rs = 31
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STXR - Store Exclusive Register (32-bit)
/// Encoding: size|001000|0|0|0|Rs|0|Rt2|Rn|Rt
fn emitStxrW(status: Reg, src: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rs = hwEnc(status);
    const rt = hwEnc(src);
    const rn = hwEnc(base);

    const insn: u32 = (0b10 << 30) | // size = word
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (0 << 22) | // L = store
        (0 << 21) | // o0
        (@as(u32, rs) << 16) | // Rs = status register
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STXR - Store Exclusive Register (64-bit)
fn emitStxrX(status: Reg, src: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rs = hwEnc(status);
    const rt = hwEnc(src);
    const rn = hwEnc(base);

    const insn: u32 = (0b11 << 30) | // size = doubleword
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (0 << 22) | // L = store
        (0 << 21) | // o0
        (@as(u32, rs) << 16) | // Rs = status register
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STXRB - Store Exclusive Register Byte
fn emitStxrb(status: Reg, src: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rs = hwEnc(status);
    const rt = hwEnc(src);
    const rn = hwEnc(base);

    const insn: u32 = (0b00 << 30) | // size = byte
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (0 << 22) | // L = store
        (0 << 21) | // o0
        (@as(u32, rs) << 16) | // Rs = status register
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STXRH - Store Exclusive Register Halfword
fn emitStxrh(status: Reg, src: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rs = hwEnc(status);
    const rt = hwEnc(src);
    const rn = hwEnc(base);

    const insn: u32 = (0b01 << 30) | // size = halfword
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (0 << 22) | // L = store
        (0 << 21) | // o0
        (@as(u32, rs) << 16) | // Rs = status register
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDAXR - Load-Acquire Exclusive Register (32-bit)
/// Encoding: size|001000|0|1|1|Rs|0|Rt2|Rn|Rt
fn emitLdaxrW(dst: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);

    const insn: u32 = (0b10 << 30) | // size = word
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (1 << 22) | // L = load
        (1 << 21) | // o0 = acquire
        (0b11111 << 16) | // Rs = 31
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDAXR - Load-Acquire Exclusive Register (64-bit)
fn emitLdaxrX(dst: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);

    const insn: u32 = (0b11 << 30) | // size = doubleword
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (1 << 22) | // L = load
        (1 << 21) | // o0 = acquire
        (0b11111 << 16) | // Rs = 31
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDAXRB - Load-Acquire Exclusive Register Byte
fn emitLdaxrb(dst: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);

    const insn: u32 = (0b00 << 30) | // size = byte
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (1 << 22) | // L = load
        (1 << 21) | // o0 = acquire
        (0b11111 << 16) | // Rs = 31
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDAXRH - Load-Acquire Exclusive Register Halfword
fn emitLdaxrh(dst: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(base);

    const insn: u32 = (0b01 << 30) | // size = halfword
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (1 << 22) | // L = load
        (1 << 21) | // o0 = acquire
        (0b11111 << 16) | // Rs = 31
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STLXR - Store-Release Exclusive Register (32-bit)
/// Encoding: size|001000|0|0|1|Rs|0|Rt2|Rn|Rt
fn emitStlxrW(status: Reg, src: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rs = hwEnc(status);
    const rt = hwEnc(src);
    const rn = hwEnc(base);

    const insn: u32 = (0b10 << 30) | // size = word
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (0 << 22) | // L = store
        (1 << 21) | // o0 = release
        (@as(u32, rs) << 16) | // Rs = status register
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STLXR - Store-Release Exclusive Register (64-bit)
fn emitStlxrX(status: Reg, src: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rs = hwEnc(status);
    const rt = hwEnc(src);
    const rn = hwEnc(base);

    const insn: u32 = (0b11 << 30) | // size = doubleword
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (0 << 22) | // L = store
        (1 << 21) | // o0 = release
        (@as(u32, rs) << 16) | // Rs = status register
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STLXRB - Store-Release Exclusive Register Byte
fn emitStlxrb(status: Reg, src: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rs = hwEnc(status);
    const rt = hwEnc(src);
    const rn = hwEnc(base);

    const insn: u32 = (0b00 << 30) | // size = byte
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (0 << 22) | // L = store
        (1 << 21) | // o0 = release
        (@as(u32, rs) << 16) | // Rs = status register
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// STLXRH - Store-Release Exclusive Register Halfword
fn emitStlxrh(status: Reg, src: Reg, base: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rs = hwEnc(status);
    const rt = hwEnc(src);
    const rn = hwEnc(base);

    const insn: u32 = (0b01 << 30) | // size = halfword
        (0b001000 << 24) |
        (0 << 23) | // fixed bit
        (0 << 22) | // L = store
        (1 << 21) | // o0 = release
        (@as(u32, rs) << 16) | // Rs = status register
        (0 << 15) | // o1
        (0b11111 << 10) | // Rt2 = 31
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

// === Atomic Operations (ARMv8.1-A LSE) ===

/// Helper for atomic memory operations
/// Encoding: size|111|V=0|00|A|R|1|Rs|opc|00|Rn|Rt
fn emitAtomicOp(dst: Reg, src: Reg, base: Reg, size: OperandSize, opc: u3, ar_bits: u2, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(dst);
    const rs = hwEnc(src);
    const rn = hwEnc(base);

    const insn: u32 = (sf_bit << 30) |
        (0b111 << 27) | // fixed
        (0 << 26) | // V = 0 (general purpose regs)
        (0b00 << 24) | // fixed
        (@as(u32, ar_bits) << 22) | // A and R bits for acquire/release
        (1 << 21) | // fixed
        (@as(u32, rs) << 16) | // source register
        (@as(u32, opc) << 12) | // operation
        (0b00 << 10) | // fixed
        (@as(u32, rn) << 5) | // base address
        rt; // destination register

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LDADD - Atomic add (no ordering)
fn emitLdadd(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b000, 0b00, buffer);
}

/// LDADDA - Atomic add with acquire
fn emitLdadda(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b000, 0b10, buffer);
}

/// LDADDAL - Atomic add with acquire-release
fn emitLdaddal(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b000, 0b11, buffer);
}

/// LDADDL - Atomic add with release
fn emitLdaddl(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b000, 0b01, buffer);
}

/// LDCLR - Atomic bit clear (no ordering)
fn emitLdclr(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b001, 0b00, buffer);
}

/// LDCLRA - Atomic bit clear with acquire
fn emitLdclra(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b001, 0b10, buffer);
}

/// LDCLRAL - Atomic bit clear with acquire-release
fn emitLdclral(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b001, 0b11, buffer);
}

/// LDCLRL - Atomic bit clear with release
fn emitLdclrl(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b001, 0b01, buffer);
}

/// LDSET - Atomic bit set (no ordering)
fn emitLdset(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b011, 0b00, buffer);
}

/// LDSETA - Atomic bit set with acquire
fn emitLdseta(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b011, 0b10, buffer);
}

/// LDSETAL - Atomic bit set with acquire-release
fn emitLdsetal(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b011, 0b11, buffer);
}

/// LDSETL - Atomic bit set with release
fn emitLdsetl(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b011, 0b01, buffer);
}

/// LDEOR - Atomic XOR (no ordering)
fn emitLdeor(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b010, 0b00, buffer);
}

/// LDEORA - Atomic XOR with acquire
fn emitLdeora(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b010, 0b10, buffer);
}

/// LDEORAL - Atomic XOR with acquire-release
fn emitLdeoral(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b010, 0b11, buffer);
}

/// LDEORL - Atomic XOR with release
fn emitLdeorl(dst: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    try emitAtomicOp(dst, src, base, size, 0b010, 0b01, buffer);
}

/// Helper for CAS operations
/// Encoding: size|00|1|0|1|0|0|0|A|R|1|Rs|o3|1|Rn|Rt
fn emitCasOp(compare: Reg, src: Reg, base: Reg, size: OperandSize, ar_bits: u2, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(compare); // compare value, also destination
    const rs = hwEnc(src); // new value to store
    const rn = hwEnc(base);

    const insn: u32 = (sf_bit << 30) |
        (0b00101000 << 22) | // fixed bits including CAS opcode
        (@as(u32, ar_bits) << 22) | // Actually AR bits are at 22-23, need to fix
        (1 << 21) | // fixed
        (@as(u32, rs) << 16) |
        (0b11111 << 10) | // fixed + o3=1
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CAS - Compare and Swap (no ordering)
fn emitCas(compare: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(compare);
    const rs = hwEnc(src);
    const rn = hwEnc(base);

    // CAS: size|0010|1000|1|0|1|Rs|0|11111|Rn|Rt
    const insn: u32 = (sf_bit << 30) |
        (0b00101000 << 22) |
        (1 << 21) |
        (@as(u32, rs) << 16) |
        (0b011111 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CASA - Compare and Swap with acquire
fn emitCasa(compare: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(compare);
    const rs = hwEnc(src);
    const rn = hwEnc(base);

    // CASA: size|0010|1000|1|1|1|Rs|0|11111|Rn|Rt (L=1 for acquire)
    const insn: u32 = (sf_bit << 30) |
        (0b00101000 << 22) |
        (1 << 22) | // L = acquire
        (1 << 21) |
        (@as(u32, rs) << 16) |
        (0b011111 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CASAL - Compare and Swap with acquire-release
fn emitCasal(compare: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(compare);
    const rs = hwEnc(src);
    const rn = hwEnc(base);

    // CASAL: size|0010|1000|1|1|1|Rs|1|11111|Rn|Rt (L=1 o0=1)
    const insn: u32 = (sf_bit << 30) |
        (0b00101000 << 22) |
        (1 << 22) | // L = acquire
        (1 << 21) |
        (@as(u32, rs) << 16) |
        (1 << 15) | // o0 = release
        (0b011111 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// CASL - Compare and Swap with release
fn emitCasl(compare: Reg, src: Reg, base: Reg, size: OperandSize, buffer: *buffer_mod.MachBuffer) !void {
    const sf_bit: u32 = @intCast(sf(size));
    const rt = hwEnc(compare);
    const rs = hwEnc(src);
    const rn = hwEnc(base);

    // CASL: size|0010|1000|1|0|1|Rs|1|11111|Rn|Rt (o0=1 for release)
    const insn: u32 = (sf_bit << 30) |
        (0b00101000 << 22) |
        (1 << 21) |
        (@as(u32, rs) << 16) |
        (1 << 15) | // o0 = release
        (0b011111 << 10) |
        (@as(u32, rn) << 5) |
        rt;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

// === Memory Barriers ===

/// DMB - Data Memory Barrier
/// Encoding: 1101010100|0|00|011|0011|CRm|1|01|11111
fn emitDmb(option: root.aarch64_inst.BarrierOption, buffer: *buffer_mod.MachBuffer) !void {
    const crm: u32 = @intFromEnum(option);

    const insn: u32 = (0b11010101000000110011 << 12) |
        (crm << 8) |
        0b10111111;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// DSB - Data Synchronization Barrier
/// Encoding: 1101010100|0|00|011|0011|CRm|1|00|11111
fn emitDsb(option: root.aarch64_inst.BarrierOption, buffer: *buffer_mod.MachBuffer) !void {
    const crm: u32 = @intFromEnum(option);

    const insn: u32 = (0b11010101000000110011 << 12) |
        (crm << 8) |
        0b10011111;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ISB - Instruction Synchronization Barrier
/// Encoding: 1101010100|0|00|011|0011|1111|1|11|11111
fn emitIsb(buffer: *buffer_mod.MachBuffer) !void {
    const insn: u32 = (0b11010101000000110011 << 12) |
        (0b1111 << 8) |
        0b11111111;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// B label (unconditional branch)
fn emitB(label: u32, buffer: *buffer_mod.MachBuffer) !void {
    // B: 0|00101|imm26
    const insn: u32 = (0b00101 << 26);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);

    // Add label use for fixup
    try buffer.useLabel(
        buffer_mod.MachLabel.new(label),
        buffer_mod.LabelUseKind.branch26,
    );
}

/// B.cond label (conditional branch)
fn emitBCond(cond: u8, label: u32, buffer: *buffer_mod.MachBuffer) !void {
    // B.cond: 01010100|imm19|0|cond
    const insn: u32 = (0b01010100 << 24) | @as(u32, cond);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);

    // Add label use for fixup
    try buffer.useLabel(
        buffer_mod.MachLabel.new(label),
        buffer_mod.LabelUseKind.branch19,
    );
}

/// BL label (branch and link)
fn emitBL(label: u32, buffer: *buffer_mod.MachBuffer) !void {
    // BL: 1|00101|imm26
    const insn: u32 = (0b100101 << 26);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);

    // Add label use for fixup
    try buffer.useLabel(
        buffer_mod.MachLabel.new(label),
        buffer_mod.LabelUseKind.branch26,
    );
}

/// BR Xn (branch to register)
fn emitBR(target: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rn = hwEnc(target);

    // BR: 1101011|0000|11111|000000|Rn|00000
    const insn: u32 = (0b1101011000011111000000 << 10) |
        (@as(u32, rn) << 5);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// BLR Xn (branch and link to register)
fn emitBLR(target: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rn = hwEnc(target);

    // BLR: 1101011|0001|11111|000000|Rn|00000
    const insn: u32 = (0b1101011000111111000000 << 10) |
        (@as(u32, rn) << 5);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// RET [Xn] (return from subroutine)
fn emitRet(reg: ?Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rn = if (reg) |r| hwEnc(r) else 30; // Default to X30 (LR)

    // RET: 1101011|0010|11111|000000|Rn|00000
    const insn: u32 = (0b1101011001011111000000 << 10) |
        (@as(u32, rn) << 5);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// NOP
fn emitNop(buffer: *buffer_mod.MachBuffer) !void {
    // NOP: 11010101000000110010000011111111
    const insn: u32 = 0xD503201F;
    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

// === Floating-Point Instructions ===

/// FADD Sd, Sn, Sm (scalar single-precision)
/// Encoding: 0|0|0|11110|00|1|Rm|001010|Rn|Rd
fn emitFaddS(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) | // M=0, S=0, ptype=00
        (0b11110 << 24) | // FP data-processing
        (0b00 << 22) | // ftype=00 (single-precision)
        (0b1 << 21) | // fixed
        (@as(u32, rm) << 16) |
        (0b001010 << 10) | // opcode for FADD
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FADD Dd, Dn, Dm (scalar double-precision)
/// Encoding: 0|0|0|11110|01|1|Rm|001010|Rn|Rd
fn emitFaddD(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) | // ftype=01 (double-precision)
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b001010 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FSUB Sd, Sn, Sm (scalar single-precision)
/// Encoding: 0|0|0|11110|00|1|Rm|001110|Rn|Rd
fn emitFsubS(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b001110 << 10) | // opcode for FSUB
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FSUB Dd, Dn, Dm (scalar double-precision)
/// Encoding: 0|0|0|11110|01|1|Rm|001110|Rn|Rd
fn emitFsubD(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b001110 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMUL Sd, Sn, Sm (scalar single-precision)
/// Encoding: 0|0|0|11110|00|1|Rm|000010|Rn|Rd
fn emitFmulS(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b000010 << 10) | // opcode for FMUL
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMUL Dd, Dn, Dm (scalar double-precision)
/// Encoding: 0|0|0|11110|01|1|Rm|000010|Rn|Rd
fn emitFmulD(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b000010 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FDIV Sd, Sn, Sm (scalar single-precision)
/// Encoding: 0|0|0|11110|00|1|Rm|000110|Rn|Rd
fn emitFdivS(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b000110 << 10) | // opcode for FDIV
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FDIV Dd, Dn, Dm (scalar double-precision)
/// Encoding: 0|0|0|11110|01|1|Rm|000110|Rn|Rd
fn emitFdivD(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b000110 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMOV Sd, Sn (scalar single-precision register)
/// Encoding: 0|0|0|11110|00|1|00000|010000|Rn|Rd
fn emitFmovRRS(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (0b00000 << 16) |
        (0b010000 << 10) | // opcode for FMOV register
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMOV Dd, Dn (scalar double-precision register)
/// Encoding: 0|0|0|11110|01|1|00000|010000|Rn|Rd
fn emitFmovRRD(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) |
        (0b1 << 21) |
        (0b00000 << 16) |
        (0b010000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMOV Sd, #imm (scalar single-precision immediate)
/// For now, only support zero (0.0f)
/// Encoding: 0|0|0|11110|00|1|imm8|10000000|Rd
fn emitFmovImmS(dst: Reg, imm: f32, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);

    // For now, only support zero
    if (imm != 0.0) {
        return error.UnsupportedFPImmediate;
    }

    // FMOV with zero uses imm8=0 which encodes +0.0
    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (0b00000000 << 13) | // imm8=0 for +0.0
        (0b100 << 10) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMOV Dd, #imm (scalar double-precision immediate)
/// For now, only support zero (0.0)
/// Encoding: 0|0|0|11110|01|1|imm8|10000000|Rd
fn emitFmovImmD(dst: Reg, imm: f64, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);

    // For now, only support zero
    if (imm != 0.0) {
        return error.UnsupportedFPImmediate;
    }

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) |
        (0b1 << 21) |
        (0b00000000 << 13) | // imm8=0 for +0.0
        (0b100 << 10) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FCMP Sn, Sm (compare single-precision)
/// Encoding: 0|0|0|11110|00|1|Rm|00|1000|Rn|opcode2
fn emitFcmpS(src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b00 << 14) |
        (0b1000 << 10) |
        (@as(u32, rn) << 5) |
        0b00000; // opcode2=00000 for register compare

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FCMP Dn, Dm (compare double-precision)
/// Encoding: 0|0|0|11110|01|1|Rm|00|1000|Rn|opcode2
fn emitFcmpD(src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b00 << 14) |
        (0b1000 << 10) |
        (@as(u32, rn) << 5) |
        0b00000;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FCVT Dd, Sn (convert single to double-precision)
/// Encoding: 0|0|0|11110|00|1|00|010|opc|10000|Rn|Rd
/// opc=01 for S->D
fn emitFcvtSToD(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) | // source type: single
        (0b1 << 21) |
        (0b00 << 19) |
        (0b010 << 16) |
        (0b01 << 15) | // opc=01 for S->D
        (0b10000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FCVT Sd, Dn (convert double to single-precision)
/// Encoding: 0|0|0|11110|01|1|00|010|opc|10000|Rn|Rd
/// opc=00 for D->S
fn emitFcvtDToS(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) | // source type: double
        (0b1 << 21) |
        (0b00 << 19) |
        (0b010 << 16) |
        (0b00 << 15) | // opc=00 for D->S
        (0b10000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SCVTF Sd, Wn (convert signed 32-bit int to single-precision)
/// Encoding: 0|0|0|11110|00|1|00|010|000000|Rn|Rd
fn emitScvtfWToS(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) | // ftype=00 (single)
        (0b1 << 21) |
        (0b00 << 19) |
        (0b010 << 16) |
        (0b000000 << 10) | // opcode for SCVTF, sf=0 (32-bit int)
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SCVTF Sd, Xn (convert signed 64-bit int to single-precision)
/// Encoding: 0|1|0|11110|00|1|00|010|000000|Rn|Rd
fn emitScvtfXToS(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b010 << 29) | // sf=1 for 64-bit int
        (0b11110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (0b00 << 19) |
        (0b010 << 16) |
        (0b000000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SCVTF Dd, Wn (convert signed 32-bit int to double-precision)
/// Encoding: 0|0|0|11110|01|1|00|010|000000|Rn|Rd
fn emitScvtfWToD(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) | // ftype=01 (double)
        (0b1 << 21) |
        (0b00 << 19) |
        (0b010 << 16) |
        (0b000000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SCVTF Dd, Xn (convert signed 64-bit int to double-precision)
/// Encoding: 0|1|0|11110|01|1|00|010|000000|Rn|Rd
fn emitScvtfXToD(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b010 << 29) | // sf=1 for 64-bit int
        (0b11110 << 24) |
        (0b01 << 22) |
        (0b1 << 21) |
        (0b00 << 19) |
        (0b010 << 16) |
        (0b000000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FCVTZS Wd, Sn (convert single-precision to signed 32-bit int, toward zero)
/// Encoding: 0|0|0|11110|00|1|11|000|000000|Rn|Rd
fn emitFcvtzsSTow(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) | // ftype=00 (single)
        (0b1 << 21) |
        (0b11 << 19) | // rmode=11 (toward zero)
        (0b000 << 16) |
        (0b000000 << 10) | // opcode for FCVTZS, sf=0 (32-bit int)
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FCVTZS Xd, Sn (convert single-precision to signed 64-bit int, toward zero)
/// Encoding: 0|1|0|11110|00|1|11|000|000000|Rn|Rd
fn emitFcvtzsSToX(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b010 << 29) | // sf=1 for 64-bit int
        (0b11110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (0b11 << 19) |
        (0b000 << 16) |
        (0b000000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FCVTZS Wd, Dn (convert double-precision to signed 32-bit int, toward zero)
/// Encoding: 0|0|0|11110|01|1|11|000|000000|Rn|Rd
fn emitFcvtzsDToW(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) | // ftype=01 (double)
        (0b1 << 21) |
        (0b11 << 19) |
        (0b000 << 16) |
        (0b000000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FCVTZS Xd, Dn (convert double-precision to signed 64-bit int, toward zero)
/// Encoding: 0|1|0|11110|01|1|11|000|000000|Rn|Rd
fn emitFcvtzsDToX(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b010 << 29) | // sf=1 for 64-bit int
        (0b11110 << 24) |
        (0b01 << 22) |
        (0b1 << 21) |
        (0b11 << 19) |
        (0b000 << 16) |
        (0b000000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FNEG Sd, Sn (negate single-precision)
/// Encoding: 0|0|0|11110|00|1|00000|010010|Rn|Rd
fn emitFnegS(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (0b00000 << 16) |
        (0b010010 << 10) | // opcode for FNEG
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FNEG Dd, Dn (negate double-precision)
/// Encoding: 0|0|0|11110|01|1|00000|010010|Rn|Rd
fn emitFnegD(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) |
        (0b1 << 21) |
        (0b00000 << 16) |
        (0b010010 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FABS Sd, Sn (absolute value single-precision)
/// Encoding: 0|0|0|11110|00|1|00000|010001|Rn|Rd
fn emitFabsS(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (0b00000 << 16) |
        (0b010001 << 10) | // opcode for FABS
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FABS Dd, Dn (absolute value double-precision)
/// Encoding: 0|0|0|11110|01|1|00000|010001|Rn|Rd
fn emitFabsD(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) |
        (0b1 << 21) |
        (0b00000 << 16) |
        (0b010001 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMAX Sd, Sn, Sm (maximum single-precision)
/// Encoding: 0|0|0|11110|00|1|Rm|010010|Rn|Rd
fn emitFmaxS(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b010010 << 10) | // opcode for FMAX
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMAX Dd, Dn, Dm (maximum double-precision)
/// Encoding: 0|0|0|11110|01|1|Rm|010010|Rn|Rd
fn emitFmaxD(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b010010 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMIN Sd, Sn, Sm (minimum single-precision)
/// Encoding: 0|0|0|11110|00|1|Rm|010110|Rn|Rd
fn emitFminS(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b010110 << 10) | // opcode for FMIN
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMIN Dd, Dn, Dm (minimum double-precision)
/// Encoding: 0|0|0|11110|01|1|Rm|010110|Rn|Rd
fn emitFminD(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b010110 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FRINTZ Sd, Sn (round toward zero, single-precision)
/// Encoding: 0|0|0|11110|00|1|001|011|10000|Rn|Rd
fn emitFrintzS(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) | // type=00 for f32
        (0b1 << 21) |
        (0b001 << 18) |
        (0b011 << 15) | // rmode=011 for FRINTZ
        (0b10000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FRINTZ Dd, Dn (round toward zero, double-precision)
/// Encoding: 0|0|0|11110|01|1|001|011|10000|Rn|Rd
fn emitFrintzD(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) | // type=01 for f64
        (0b1 << 21) |
        (0b001 << 18) |
        (0b011 << 15) | // rmode=011 for FRINTZ
        (0b10000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FRINTP Sd, Sn (round toward +infinity, single-precision)
/// Encoding: 0|0|0|11110|00|1|001|010|10000|Rn|Rd
fn emitFrintpS(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) | // type=00 for f32
        (0b1 << 21) |
        (0b001 << 18) |
        (0b010 << 15) | // rmode=010 for FRINTP
        (0b10000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FRINTP Dd, Dn (round toward +infinity, double-precision)
/// Encoding: 0|0|0|11110|01|1|001|010|10000|Rn|Rd
fn emitFrintpD(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) | // type=01 for f64
        (0b1 << 21) |
        (0b001 << 18) |
        (0b010 << 15) | // rmode=010 for FRINTP
        (0b10000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FRINTM Sd, Sn (round toward -infinity, single-precision)
/// Encoding: 0|0|0|11110|00|1|001|001|10000|Rn|Rd
fn emitFrintmS(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) | // type=00 for f32
        (0b1 << 21) |
        (0b001 << 18) |
        (0b001 << 15) | // rmode=001 for FRINTM
        (0b10000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FRINTM Dd, Dn (round toward -infinity, double-precision)
/// Encoding: 0|0|0|11110|01|1|001|001|10000|Rn|Rd
fn emitFrintmD(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) | // type=01 for f64
        (0b1 << 21) |
        (0b001 << 18) |
        (0b001 << 15) | // rmode=001 for FRINTM
        (0b10000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FRINTA Sd, Sn (round to nearest, ties to away, single-precision)
/// Encoding: 0|0|0|11110|00|1|001|000|10000|Rn|Rd
fn emitFrintaS(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b00 << 22) | // type=00 for f32
        (0b1 << 21) |
        (0b001 << 18) |
        (0b000 << 15) | // rmode=000 for FRINTA
        (0b10000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FRINTA Dd, Dn (round to nearest, ties to away, double-precision)
/// Encoding: 0|0|0|11110|01|1|001|000|10000|Rn|Rd
fn emitFrintaD(dst: Reg, src: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const insn: u32 = (0b000 << 29) |
        (0b11110 << 24) |
        (0b01 << 22) | // type=01 for f64
        (0b1 << 21) |
        (0b001 << 18) |
        (0b000 << 15) | // rmode=000 for FRINTA
        (0b10000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMADD Sd, Sn, Sm, Sa (fused multiply-add, single-precision)
/// d = a + (n * m)
/// Encoding: 0|0|0|11111|00|0|Rm|0|Ra|Rn|Rd
fn emitFmaddS(dst: Reg, src_n: Reg, src_m: Reg, src_a: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src_n);
    const rm = hwEnc(src_m);
    const ra = hwEnc(src_a);

    const insn: u32 = (0b000 << 29) |
        (0b11111 << 24) |
        (0b00 << 22) | // type=00 for f32
        (0b0 << 21) |
        (@as(u32, rm) << 16) |
        (0b0 << 15) | // o1=0 for FMADD
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMADD Dd, Dn, Dm, Da (fused multiply-add, double-precision)
/// d = a + (n * m)
/// Encoding: 0|0|0|11111|01|0|Rm|0|Ra|Rn|Rd
fn emitFmaddD(dst: Reg, src_n: Reg, src_m: Reg, src_a: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src_n);
    const rm = hwEnc(src_m);
    const ra = hwEnc(src_a);

    const insn: u32 = (0b000 << 29) |
        (0b11111 << 24) |
        (0b01 << 22) | // type=01 for f64
        (0b0 << 21) |
        (@as(u32, rm) << 16) |
        (0b0 << 15) | // o1=0 for FMADD
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMSUB Sd, Sn, Sm, Sa (fused multiply-subtract, single-precision)
/// d = a - (n * m)
/// Encoding: 0|0|0|11111|00|0|Rm|1|Ra|Rn|Rd
fn emitFmsubS(dst: Reg, src_n: Reg, src_m: Reg, src_a: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src_n);
    const rm = hwEnc(src_m);
    const ra = hwEnc(src_a);

    const insn: u32 = (0b000 << 29) |
        (0b11111 << 24) |
        (0b00 << 22) | // type=00 for f32
        (0b0 << 21) |
        (@as(u32, rm) << 16) |
        (0b1 << 15) | // o1=1 for FMSUB
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FMSUB Dd, Dn, Dm, Da (fused multiply-subtract, double-precision)
/// d = a - (n * m)
/// Encoding: 0|0|0|11111|01|0|Rm|1|Ra|Rn|Rd
fn emitFmsubD(dst: Reg, src_n: Reg, src_m: Reg, src_a: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src_n);
    const rm = hwEnc(src_m);
    const ra = hwEnc(src_a);

    const insn: u32 = (0b000 << 29) |
        (0b11111 << 24) |
        (0b01 << 22) | // type=01 for f64
        (0b0 << 21) |
        (@as(u32, rm) << 16) |
        (0b1 << 15) | // o1=1 for FMSUB
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FNMADD Sd, Sn, Sm, Sa (fused negate multiply-add, single-precision)
/// d = -a - (n * m)
/// Encoding: 0|0|0|11111|00|1|Rm|0|Ra|Rn|Rd
fn emitFnmaddS(dst: Reg, src_n: Reg, src_m: Reg, src_a: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src_n);
    const rm = hwEnc(src_m);
    const ra = hwEnc(src_a);

    const insn: u32 = (0b000 << 29) |
        (0b11111 << 24) |
        (0b00 << 22) | // type=00 for f32
        (0b1 << 21) | // M=1 for negated variants
        (@as(u32, rm) << 16) |
        (0b0 << 15) | // o1=0 for FNMADD
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FNMADD Dd, Dn, Dm, Da (fused negate multiply-add, double-precision)
/// d = -a - (n * m)
/// Encoding: 0|0|0|11111|01|1|Rm|0|Ra|Rn|Rd
fn emitFnmaddD(dst: Reg, src_n: Reg, src_m: Reg, src_a: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src_n);
    const rm = hwEnc(src_m);
    const ra = hwEnc(src_a);

    const insn: u32 = (0b000 << 29) |
        (0b11111 << 24) |
        (0b01 << 22) | // type=01 for f64
        (0b1 << 21) | // M=1 for negated variants
        (@as(u32, rm) << 16) |
        (0b0 << 15) | // o1=0 for FNMADD
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FNMSUB Sd, Sn, Sm, Sa (fused negate multiply-subtract, single-precision)
/// d = -a + (n * m)
/// Encoding: 0|0|0|11111|00|1|Rm|1|Ra|Rn|Rd
fn emitFnmsubS(dst: Reg, src_n: Reg, src_m: Reg, src_a: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src_n);
    const rm = hwEnc(src_m);
    const ra = hwEnc(src_a);

    const insn: u32 = (0b000 << 29) |
        (0b11111 << 24) |
        (0b00 << 22) | // type=00 for f32
        (0b1 << 21) | // M=1 for negated variants
        (@as(u32, rm) << 16) |
        (0b1 << 15) | // o1=1 for FNMSUB
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// FNMSUB Dd, Dn, Dm, Da (fused negate multiply-subtract, double-precision)
/// d = -a + (n * m)
/// Encoding: 0|0|0|11111|01|1|Rm|1|Ra|Rn|Rd
fn emitFnmsubD(dst: Reg, src_n: Reg, src_m: Reg, src_a: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src_n);
    const rm = hwEnc(src_m);
    const ra = hwEnc(src_a);

    const insn: u32 = (0b000 << 29) |
        (0b11111 << 24) |
        (0b01 << 22) | // type=01 for f64
        (0b1 << 21) | // M=1 for negated variants
        (@as(u32, rm) << 16) |
        (0b1 << 15) | // o1=1 for FNMSUB
        (@as(u32, ra) << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}


/// ADR Xd, #offset
/// Form PC-relative address: Xd = PC + offset (±1MB range)
/// Encoding: op|immlo|10000|immhi|Rd
/// op=0 for ADR, immlo is bits [1:0] of offset, immhi is bits [20:2]
fn emitAdr(dst: Reg, offset: i32, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);

    // Check offset is within ±1MB range (21-bit signed)
    if (offset < -(1 << 20) or offset > ((1 << 20) - 1)) {
        return error.OffsetOutOfRange;
    }

    // Extract immlo (bits [1:0]) and immhi (bits [20:2])
    const offset_u: u32 = @bitCast(offset);
    const immlo: u2 = @truncate(offset_u & 0x3);
    const immhi: u19 = @truncate((offset_u >> 2) & 0x7FFFF);

    // ADR: 0|immlo|10000|immhi|Rd
    const insn: u32 = (0 << 31) | // op = 0 for ADR
        (@as(u32, immlo) << 29) |
        (0b10000 << 24) |
        (@as(u32, immhi) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ADRP Xd, #offset
/// Form PC-relative address to 4KB page: Xd = (PC & ~0xFFF) + (offset << 12)
/// Encoding: op|immlo|10000|immhi|Rd
/// op=1 for ADRP, immlo is bits [1:0] of offset, immhi is bits [20:2]
fn emitAdrp(dst: Reg, offset: i32, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);

    // Check offset is within ±1MB range (21-bit signed page offset)
    // When shifted left by 12, this gives ±4GB range
    if (offset < -(1 << 20) or offset > ((1 << 20) - 1)) {
        return error.OffsetOutOfRange;
    }

    // Extract immlo (bits [1:0]) and immhi (bits [20:2])
    const offset_u: u32 = @bitCast(offset);
    const immlo: u2 = @truncate(offset_u & 0x3);
    const immhi: u19 = @truncate((offset_u >> 2) & 0x7FFFF);

    // ADRP: 1|immlo|10000|immhi|Rd
    const insn: u32 = (1 << 31) | // op = 1 for ADRP
        (@as(u32, immlo) << 29) |
        (0b10000 << 24) |
        (@as(u32, immhi) << 5) |
        rd;

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

test "emit nop" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try emit(.nop, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    try testing.expectEqual(@as(u32, 0xD503201F), std.mem.bytesToValue(u32, buffer.data.items[0..4]));
}

test "emit ret" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    try emit(.{ .ret = .{ .reg = null } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    // RET defaults to X30
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 30), (insn >> 5) & 0x1F);
}

test "emit mov imm" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .mov_imm = .{
        .dst = wr0,
        .imm = 42,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31)
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check immediate (bits 5-20)
    try testing.expectEqual(@as(u32, 42), (insn >> 5) & 0xFFFF);
}

test "emit add rr" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .add_rr = .{
        .dst = wr0,
        .src1 = r0,
        .src2 = r1,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
}

test "emit add shifted" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // Test: ADD X0, X1, X2, LSL #3
    try emit(.{ .add_shifted = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .shift_op = .lsl,
        .shift_amt = 3,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opc+S bits (bits 29-30) = 00 for ADD
    try testing.expectEqual(@as(u32, 0b00), (insn >> 29) & 0b11);

    // Check opcode field (bits 24-28) = 0b01011 for ADD/SUB shifted register
    try testing.expectEqual(@as(u32, 0b01011), (insn >> 24) & 0b11111);

    // Check shift type (bits 22-23) = 00 for LSL
    try testing.expectEqual(@as(u32, 0b00), (insn >> 22) & 0b11);

    // Check shift amount (bits 10-15) = 3
    try testing.expectEqual(@as(u32, 3), (insn >> 10) & 0b111111);

    // Check register encodings
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // Rd = X0
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F); // Rn = X1
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F); // Rm = X2
}

test "emit mul rr" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .mul_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode field (bits 21-28) = 0b11011000
    try testing.expectEqual(@as(u32, 0b11011000), (insn >> 21) & 0xFF);

    // Check Ra field (bits 10-14) = 31 (XZR)
    try testing.expectEqual(@as(u32, 31), (insn >> 10) & 0x1F);
}

test "emit madd" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const v3 = root.reg.VReg.new(3, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const r3 = Reg.fromVReg(v3);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .madd = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .addend = r3,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check opcode field
    try testing.expectEqual(@as(u32, 0b11011000), (insn >> 21) & 0xFF);

    // Check o0 bit (bit 15) = 0 for MADD
    try testing.expectEqual(@as(u32, 0), (insn >> 15) & 1);
}

test "emit msub" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const v3 = root.reg.VReg.new(3, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const r3 = Reg.fromVReg(v3);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .msub = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .subtrahend = r3,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check o0 bit (bit 15) = 1 for MSUB
    try testing.expectEqual(@as(u32, 1), (insn >> 15) & 1);
}

test "emit smulh" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .smulh = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 (always 64-bit)
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode field (bits 21-28) = 0b11011010
    try testing.expectEqual(@as(u32, 0b11011010), (insn >> 21) & 0xFF);
}

test "emit umulh" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    try emit(.{ .umulh = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check opcode field (bits 21-28) = 0b11011110
    try testing.expectEqual(@as(u32, 0b11011110), (insn >> 21) & 0xFF);
}

test "emit sdiv 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r10 = Reg.fromVReg(v10);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // SDIV X3, X10, X5
    try emit(.{ .sdiv = .{
        .dst = wr3,
        .src1 = r10,
        .src2 = r5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check bits 30-29 = 0b00
    try testing.expectEqual(@as(u32, 0b00), (insn >> 29) & 0b11);

    // Check opcode field (bits 21-28) = 0b11010110
    try testing.expectEqual(@as(u32, 0b11010110), (insn >> 21) & 0xFF);

    // Check Rm field (bits 16-20) = 5
    try testing.expectEqual(@as(u32, 5), (insn >> 16) & 0x1F);

    // Check opcode2 field (bits 11-15) = 0b00001 for SDIV
    try testing.expectEqual(@as(u32, 0b00001), (insn >> 11) & 0x1F);

    // Check bit 10 = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 10) & 1);

    // Check Rn field (bits 5-9) = 10
    try testing.expectEqual(@as(u32, 10), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 3
    try testing.expectEqual(@as(u32, 3), insn & 0x1F);

    // Verify complete encoding: 0x9AC50D43
    try testing.expectEqual(@as(u32, 0x9AC50D43), insn);
}

test "emit sdiv 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r10 = Reg.fromVReg(v10);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // SDIV W3, W10, W5
    try emit(.{ .sdiv = .{
        .dst = wr3,
        .src1 = r10,
        .src2 = r5,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check opcode field (bits 21-28) = 0b11010110
    try testing.expectEqual(@as(u32, 0b11010110), (insn >> 21) & 0xFF);

    // Check opcode2 field (bits 11-15) = 0b00001 for SDIV
    try testing.expectEqual(@as(u32, 0b00001), (insn >> 11) & 0x1F);

    // Verify complete encoding: 0x1AC50D43
    try testing.expectEqual(@as(u32, 0x1AC50D43), insn);
}

test "emit udiv 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r10 = Reg.fromVReg(v10);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // UDIV X3, X10, X5
    try emit(.{ .udiv = .{
        .dst = wr3,
        .src1 = r10,
        .src2 = r5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check bits 30-29 = 0b00
    try testing.expectEqual(@as(u32, 0b00), (insn >> 29) & 0b11);

    // Check opcode field (bits 21-28) = 0b11010110
    try testing.expectEqual(@as(u32, 0b11010110), (insn >> 21) & 0xFF);

    // Check Rm field (bits 16-20) = 5
    try testing.expectEqual(@as(u32, 5), (insn >> 16) & 0x1F);

    // Check bits 15-11 = 0b00001 (same as SDIV)
    try testing.expectEqual(@as(u32, 0b00001), (insn >> 11) & 0x1F);

    // Check bit 10 = 0 for UDIV (distinguishes from SDIV)
    try testing.expectEqual(@as(u32, 0), (insn >> 10) & 1);

    // Check Rn field (bits 5-9) = 10
    try testing.expectEqual(@as(u32, 10), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 3
    try testing.expectEqual(@as(u32, 3), insn & 0x1F);

    // Verify complete encoding: 0x9AC50943
    try testing.expectEqual(@as(u32, 0x9AC50943), insn);
}

test "emit udiv 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r10 = Reg.fromVReg(v10);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // UDIV W3, W10, W5
    try emit(.{ .udiv = .{
        .dst = wr3,
        .src1 = r10,
        .src2 = r5,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check opcode field (bits 21-28) = 0b11010110
    try testing.expectEqual(@as(u32, 0b11010110), (insn >> 21) & 0xFF);

    // Check bits 15-11 = 0b00001 (same as SDIV)
    try testing.expectEqual(@as(u32, 0b00001), (insn >> 11) & 0x1F);

    // Check bit 10 = 0 for UDIV
    try testing.expectEqual(@as(u32, 0), (insn >> 10) & 1);

    // Verify complete encoding: 0x1AC50943
    try testing.expectEqual(@as(u32, 0x1AC50943), insn);
}

test "emit divide with different registers" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // SDIV X0, X1, X2
    try emit(.{ .sdiv = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check Rd = 0, Rn = 1, Rm = 2
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F);
}

test "emit and rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // AND X0, X1, X2
    try emit(.{ .and_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 29-21) = 0b00001010 for AND
    try testing.expectEqual(@as(u32, 0b00001010), (insn >> 21) & 0x3FF);

    // Check Rd = 0, Rn = 1, Rm = 2
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F);
}

test "emit and rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const r5 = Reg.fromVReg(v5);
    const r10 = Reg.fromVReg(v10);
    const r7 = Reg.fromVReg(v7);
    const wr5 = root.reg.WritableReg.fromReg(r5);

    // AND W5, W10, W7
    try emit(.{ .and_rr = .{
        .dst = wr5,
        .src1 = r10,
        .src2 = r7,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x0A070145 (AND W5, W10, W7)
    try testing.expectEqual(@as(u32, 0x0A070145), insn);
}

test "emit and imm 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r1 = Reg.fromVReg(v1);
    const wr2 = root.reg.WritableReg.fromReg(Reg.fromVReg(v2));

    // AND X2, X1, #0xff (example with simple bitmask)
    const imm_logic = root.aarch64_inst.ImmLogic{
        .value = 0xff,
        .n = true, // N=1 for 64-bit patterns
        .r = 0, // immr
        .s = 7, // imms (8 consecutive 1s)
        .size = .size64,
    };

    try emit(.{ .and_imm = .{
        .dst = wr2,
        .src = r1,
        .imm = imm_logic,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 29-23) = 0b00100100 for AND immediate
    try testing.expectEqual(@as(u32, 0b00100100), (insn >> 23) & 0x7F);

    // Check N bit
    try testing.expectEqual(@as(u32, 1), (insn >> 22) & 1);

    // Check immr and imms fields
    try testing.expectEqual(@as(u32, 0), (insn >> 16) & 0x3F);
    try testing.expectEqual(@as(u32, 7), (insn >> 10) & 0x3F);

    // Check registers
    try testing.expectEqual(@as(u32, 2), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
}

test "emit orr rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // ORR X3, X4, X5
    try emit(.{ .orr_rr = .{
        .dst = wr3,
        .src1 = r4,
        .src2 = r5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 29-21) = 0b01001010 for ORR
    try testing.expectEqual(@as(u32, 0b01001010), (insn >> 21) & 0x3FF);

    // Verify complete encoding: 0xAA050083 (ORR X3, X4, X5)
    try testing.expectEqual(@as(u32, 0xAA050083), insn);
}

test "emit eor rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);
    const wr6 = root.reg.WritableReg.fromReg(r6);

    // EOR X6, X7, X8
    try emit(.{ .eor_rr = .{
        .dst = wr6,
        .src1 = r7,
        .src2 = r8,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 29-21) = 0b10001010 for EOR
    try testing.expectEqual(@as(u32, 0b10001010), (insn >> 21) & 0x3FF);

    // Verify complete encoding: 0xCA0800E6 (EOR X6, X7, X8)
    try testing.expectEqual(@as(u32, 0xCA0800E6), insn);
}

test "emit mvn rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v9 = root.reg.VReg.new(9, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const r9 = Reg.fromVReg(v9);
    const r10 = Reg.fromVReg(v10);
    const wr9 = root.reg.WritableReg.fromReg(r9);

    // MVN X9, X10 (implemented as ORN X9, XZR, X10)
    try emit(.{ .mvn_rr = .{
        .dst = wr9,
        .src = r10,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode for ORN (bits 29-21 should be 0b01001010001)
    // Note: ORN has bit 21 set compared to ORR
    try testing.expectEqual(@as(u32, 0b01001010001), (insn >> 21) & 0x7FF);

    // Check Rn = 31 (XZR)
    try testing.expectEqual(@as(u32, 31), (insn >> 5) & 0x1F);

    // Check Rm = 10 and Rd = 9
    try testing.expectEqual(@as(u32, 10), (insn >> 16) & 0x1F);
    try testing.expectEqual(@as(u32, 9), insn & 0x1F);

    // Verify complete encoding: 0xAA2A03E9 (ORN X9, XZR, X10 == MVN X9, X10)
    try testing.expectEqual(@as(u32, 0xAA2A03E9), insn);
}

test "emit mvn rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // MVN W0, W1
    try emit(.{ .mvn_rr = .{
        .dst = wr0,
        .src = r1,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x2A2103E0 (ORN W0, WZR, W1 == MVN W0, W1)
    try testing.expectEqual(@as(u32, 0x2A2103E0), insn);
}

test "emit neg 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const v6 = root.reg.VReg.new(6, .int);
    const r5 = Reg.fromVReg(v5);
    const r6 = Reg.fromVReg(v6);
    const wr5 = root.reg.WritableReg.fromReg(r5);

    // NEG X5, X6 (implemented as SUB X5, XZR, X6)
    try emit(.{ .neg = .{
        .dst = wr5,
        .src = r6,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode for SUB (bits 29-24 should be 0b101011 for SUB shifted register)
    try testing.expectEqual(@as(u32, 0b101011), (insn >> 24) & 0x3F);

    // Check Rn = 31 (XZR)
    try testing.expectEqual(@as(u32, 31), (insn >> 5) & 0x1F);

    // Check Rm = 6 and Rd = 5
    try testing.expectEqual(@as(u32, 6), (insn >> 16) & 0x1F);
    try testing.expectEqual(@as(u32, 5), insn & 0x1F);

    // Verify complete encoding: 0xCB0603E5 (SUB X5, XZR, X6 == NEG X5, X6)
    try testing.expectEqual(@as(u32, 0xCB0603E5), insn);
}

test "emit neg 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // NEG W3, W4 (implemented as SUB W3, WZR, W4)
    try emit(.{ .neg = .{
        .dst = wr3,
        .src = r4,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check Rn = 31 (WZR)
    try testing.expectEqual(@as(u32, 31), (insn >> 5) & 0x1F);

    // Verify complete encoding: 0x4B0403E3 (SUB W3, WZR, W4 == NEG W3, W4)
    try testing.expectEqual(@as(u32, 0x4B0403E3), insn);
}

test "emit ngc 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);
    const wr7 = root.reg.WritableReg.fromReg(r7);

    // NGC X7, X8 (implemented as SBC X7, XZR, X8)
    try emit(.{ .ngc = .{
        .dst = wr7,
        .src = r8,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode for SBC (bits 30-21 should be 0b1011010000)
    try testing.expectEqual(@as(u32, 0b1011010000), (insn >> 21) & 0x3FF);

    // Check Rn = 31 (XZR)
    try testing.expectEqual(@as(u32, 31), (insn >> 5) & 0x1F);

    // Check Rm = 8 and Rd = 7
    try testing.expectEqual(@as(u32, 8), (insn >> 16) & 0x1F);
    try testing.expectEqual(@as(u32, 7), insn & 0x1F);

    // Verify complete encoding: 0xDA0803E7 (SBC X7, XZR, X8 == NGC X7, X8)
    try testing.expectEqual(@as(u32, 0xDA0803E7), insn);
}

test "emit ngc 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v11 = root.reg.VReg.new(11, .int);
    const v12 = root.reg.VReg.new(12, .int);
    const r11 = Reg.fromVReg(v11);
    const r12 = Reg.fromVReg(v12);
    const wr11 = root.reg.WritableReg.fromReg(r11);

    // NGC W11, W12 (implemented as SBC W11, WZR, W12)
    try emit(.{ .ngc = .{
        .dst = wr11,
        .src = r12,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check Rn = 31 (WZR)
    try testing.expectEqual(@as(u32, 31), (insn >> 5) & 0x1F);

    // Verify complete encoding: 0x5A0C03EB (SBC W11, WZR, W12 == NGC W11, W12)
    try testing.expectEqual(@as(u32, 0x5A0C03EB), insn);
}

test "neg is alias for sub with xzr" {
    // Verify that NEG produces the exact same encoding as SUB with XZR as first source
    var buffer1 = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer1.deinit();
    var buffer2 = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer2.deinit();

    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    // Emit NEG X1, X2
    try emit(.{ .neg = .{
        .dst = wr1,
        .src = r2,
        .size = .size64,
    } }, &buffer1);

    // Emit SUB X1, XZR, X2
    const xzr = Reg.fromPReg(root.reg.PReg.xzr);
    const wxzr = root.reg.WritableReg.fromReg(r1);
    try emit(.{ .sub_rr = .{
        .dst = wxzr,
        .src1 = xzr,
        .src2 = r2,
        .size = .size64,
    } }, &buffer2);

    // Both should produce identical encodings
    try testing.expectEqual(buffer1.data.items.len, buffer2.data.items.len);
    const insn1 = std.mem.bytesToValue(u32, buffer1.data.items[0..4]);
    const insn2 = std.mem.bytesToValue(u32, buffer2.data.items[0..4]);
    try testing.expectEqual(insn1, insn2);
}

test "emit adds rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // ADDS X0, X1, X2
    try emit(.{ .adds_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for ADDS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b0101011 for ADD/ADDS
    try testing.expectEqual(@as(u32, 0b0101011), (insn >> 24) & 0x7F);

    // Check Rd = 0, Rn = 1, Rm = 2
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F);

    // Verify complete encoding: 0xAB020020 (ADDS X0, X1, X2)
    try testing.expectEqual(@as(u32, 0xAB020020), insn);
}

test "emit adds rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // ADDS W3, W4, W5
    try emit(.{ .adds_rr = .{
        .dst = wr3,
        .src1 = r4,
        .src2 = r5,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for ADDS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Verify complete encoding: 0x2B050083 (ADDS W3, W4, W5)
    try testing.expectEqual(@as(u32, 0x2B050083), insn);
}

test "emit adds imm 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const wr10 = root.reg.WritableReg.fromReg(r10);

    // ADDS X10, X11, #42
    try emit(.{ .adds_imm = .{
        .dst = wr10,
        .src = r11,
        .imm = 42,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for ADDS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b0100010 for immediate form
    try testing.expectEqual(@as(u32, 0b0100010), (insn >> 24) & 0x7F);

    // Check immediate value = 42
    try testing.expectEqual(@as(u32, 42), (insn >> 10) & 0xFFF);

    // Check Rd = 10, Rn = 11
    try testing.expectEqual(@as(u32, 10), insn & 0x1F);
    try testing.expectEqual(@as(u32, 11), (insn >> 5) & 0x1F);

    // Verify complete encoding: 0xB100A96A (ADDS X10, X11, #42)
    try testing.expectEqual(@as(u32, 0xB100A96A), insn);
}

test "emit adds imm 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const v21 = root.reg.VReg.new(21, .int);
    const r20 = Reg.fromVReg(v20);
    const r21 = Reg.fromVReg(v21);
    const wr20 = root.reg.WritableReg.fromReg(r20);

    // ADDS W20, W21, #100
    try emit(.{ .adds_imm = .{
        .dst = wr20,
        .src = r21,
        .imm = 100,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for ADDS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check immediate value = 100
    try testing.expectEqual(@as(u32, 100), (insn >> 10) & 0xFFF);

    // Verify complete encoding: 0x310192B4 (ADDS W20, W21, #100)
    try testing.expectEqual(@as(u32, 0x310192B4), insn);
}

test "emit subs rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);
    const wr6 = root.reg.WritableReg.fromReg(r6);

    // SUBS X6, X7, X8
    try emit(.{ .subs_rr = .{
        .dst = wr6,
        .src1 = r7,
        .src2 = r8,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for SUBS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b1101011 for SUB/SUBS
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 24) & 0x7F);

    // Check Rd = 6, Rn = 7, Rm = 8
    try testing.expectEqual(@as(u32, 6), insn & 0x1F);
    try testing.expectEqual(@as(u32, 7), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 8), (insn >> 16) & 0x1F);

    // Verify complete encoding: 0xEB0800E6 (SUBS X6, X7, X8)
    try testing.expectEqual(@as(u32, 0xEB0800E6), insn);
}

test "emit subs rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v12 = root.reg.VReg.new(12, .int);
    const v13 = root.reg.VReg.new(13, .int);
    const v14 = root.reg.VReg.new(14, .int);
    const r12 = Reg.fromVReg(v12);
    const r13 = Reg.fromVReg(v13);
    const r14 = Reg.fromVReg(v14);
    const wr12 = root.reg.WritableReg.fromReg(r12);

    // SUBS W12, W13, W14
    try emit(.{ .subs_rr = .{
        .dst = wr12,
        .src1 = r13,
        .src2 = r14,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for SUBS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Verify complete encoding: 0x6B0E01AC (SUBS W12, W13, W14)
    try testing.expectEqual(@as(u32, 0x6B0E01AC), insn);
}

test "emit subs imm 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v15 = root.reg.VReg.new(15, .int);
    const v16 = root.reg.VReg.new(16, .int);
    const r15 = Reg.fromVReg(v15);
    const r16 = Reg.fromVReg(v16);
    const wr15 = root.reg.WritableReg.fromReg(r15);

    // SUBS X15, X16, #777
    try emit(.{ .subs_imm = .{
        .dst = wr15,
        .src = r16,
        .imm = 777,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for SUBS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b1100010 for immediate form
    try testing.expectEqual(@as(u32, 0b1100010), (insn >> 24) & 0x7F);

    // Check immediate value = 777
    try testing.expectEqual(@as(u32, 777), (insn >> 10) & 0xFFF);

    // Check Rd = 15, Rn = 16
    try testing.expectEqual(@as(u32, 15), insn & 0x1F);
    try testing.expectEqual(@as(u32, 16), (insn >> 5) & 0x1F);

    // Verify complete encoding: 0xF10C260F (SUBS X15, X16, #777)
    try testing.expectEqual(@as(u32, 0xF10C260F), insn);
}

test "emit subs imm 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v25 = root.reg.VReg.new(25, .int);
    const v26 = root.reg.VReg.new(26, .int);
    const r25 = Reg.fromVReg(v25);
    const r26 = Reg.fromVReg(v26);
    const wr25 = root.reg.WritableReg.fromReg(r25);

    // SUBS W25, W26, #999
    try emit(.{ .subs_imm = .{
        .dst = wr25,
        .src = r26,
        .imm = 999,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for SUBS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check immediate value = 999
    try testing.expectEqual(@as(u32, 999), (insn >> 10) & 0xFFF);

    // Verify complete encoding: 0x710F9F59 (SUBS W25, W26, #999)
    try testing.expectEqual(@as(u32, 0x710F9F59), insn);
}

test "emit cmp rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    // CMP X1, X2 (alias for SUBS XZR, X1, X2)
    try emit(.{ .cmp_rr = .{
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for SUBS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b1101011 for SUB/SUBS
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 24) & 0x7F);

    // Check Rd = 31 (XZR), Rn = 1, Rm = 2
    try testing.expectEqual(@as(u32, 31), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F);

    // Verify complete encoding: 0xEB02003F (SUBS XZR, X1, X2 == CMP X1, X2)
    try testing.expectEqual(@as(u32, 0xEB02003F), insn);
}

test "emit cmp rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const r5 = Reg.fromVReg(v5);
    const r10 = Reg.fromVReg(v10);

    // CMP W5, W10
    try emit(.{ .cmp_rr = .{
        .src1 = r5,
        .src2 = r10,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x6B0A00BF (SUBS WZR, W5, W10 == CMP W5, W10)
    try testing.expectEqual(@as(u32, 0x6B0A00BF), insn);
}

test "emit cmp imm 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const r3 = Reg.fromVReg(v3);

    // CMP X3, #42 (alias for SUBS XZR, X3, #42)
    try emit(.{ .cmp_imm = .{
        .src = r3,
        .imm = 42,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for SUBS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b1100010 for immediate form
    try testing.expectEqual(@as(u32, 0b1100010), (insn >> 24) & 0x7F);

    // Check immediate value = 42
    try testing.expectEqual(@as(u32, 42), (insn >> 10) & 0xFFF);

    // Check Rd = 31 (XZR), Rn = 3
    try testing.expectEqual(@as(u32, 31), insn & 0x1F);
    try testing.expectEqual(@as(u32, 3), (insn >> 5) & 0x1F);

    // Verify complete encoding: 0xF1002A7F (SUBS XZR, X3, #42 == CMP X3, #42)
    try testing.expectEqual(@as(u32, 0xF1002A7F), insn);
}

test "emit cmp imm 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v7 = root.reg.VReg.new(7, .int);
    const r7 = Reg.fromVReg(v7);

    // CMP W7, #100
    try emit(.{ .cmp_imm = .{
        .src = r7,
        .imm = 100,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check immediate value = 100
    try testing.expectEqual(@as(u32, 100), (insn >> 10) & 0xFFF);

    // Verify complete encoding: 0x710190FF (SUBS WZR, W7, #100 == CMP W7, #100)
    try testing.expectEqual(@as(u32, 0x710190FF), insn);
}

test "emit cmn rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v8 = root.reg.VReg.new(8, .int);
    const v9 = root.reg.VReg.new(9, .int);
    const r8 = Reg.fromVReg(v8);
    const r9 = Reg.fromVReg(v9);

    // CMN X8, X9 (alias for ADDS XZR, X8, X9)
    try emit(.{ .cmn_rr = .{
        .src1 = r8,
        .src2 = r9,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for ADDS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b0101011 for ADD/ADDS
    try testing.expectEqual(@as(u32, 0b0101011), (insn >> 24) & 0x7F);

    // Check Rd = 31 (XZR), Rn = 8, Rm = 9
    try testing.expectEqual(@as(u32, 31), insn & 0x1F);
    try testing.expectEqual(@as(u32, 8), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 9), (insn >> 16) & 0x1F);

    // Verify complete encoding: 0xAB09011F (ADDS XZR, X8, X9 == CMN X8, X9)
    try testing.expectEqual(@as(u32, 0xAB09011F), insn);
}

test "emit cmn rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);

    // CMN W0, W1
    try emit(.{ .cmn_rr = .{
        .src1 = r0,
        .src2 = r1,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x2B01001F (ADDS WZR, W0, W1 == CMN W0, W1)
    try testing.expectEqual(@as(u32, 0x2B01001F), insn);
}

test "emit cmn imm 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v15 = root.reg.VReg.new(15, .int);
    const r15 = Reg.fromVReg(v15);

    // CMN X15, #255 (alias for ADDS XZR, X15, #255)
    try emit(.{ .cmn_imm = .{
        .src = r15,
        .imm = 255,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check S bit (bit 29) = 1 for ADDS
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // Check opcode (bits 30-24) = 0b0100010 for immediate form
    try testing.expectEqual(@as(u32, 0b0100010), (insn >> 24) & 0x7F);

    // Check immediate value = 255
    try testing.expectEqual(@as(u32, 255), (insn >> 10) & 0xFFF);

    // Check Rd = 31 (XZR), Rn = 15
    try testing.expectEqual(@as(u32, 31), insn & 0x1F);
    try testing.expectEqual(@as(u32, 15), (insn >> 5) & 0x1F);

    // Verify complete encoding: 0xB1003FFF (ADDS XZR, X15, #255 == CMN X15, #255)
    try testing.expectEqual(@as(u32, 0xB1003FFF), insn);
}

test "emit cmn imm 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const r20 = Reg.fromVReg(v20);

    // CMN W20, #1
    try emit(.{ .cmn_imm = .{
        .src = r20,
        .imm = 1,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check immediate value = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 10) & 0xFFF);

    // Verify complete encoding: 0x3100069F (ADDS WZR, W20, #1 == CMN W20, #1)
    try testing.expectEqual(@as(u32, 0x3100069F), insn);
}

test "emit tst rr 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v12 = root.reg.VReg.new(12, .int);
    const v13 = root.reg.VReg.new(13, .int);
    const r12 = Reg.fromVReg(v12);
    const r13 = Reg.fromVReg(v13);

    // TST X12, X13 (alias for ANDS XZR, X12, X13)
    try emit(.{ .tst_rr = .{
        .src1 = r12,
        .src2 = r13,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 29-21) = 0b11001010 for ANDS
    try testing.expectEqual(@as(u32, 0b11001010), (insn >> 21) & 0x3FF);

    // Check Rd = 31 (XZR), Rn = 12, Rm = 13
    try testing.expectEqual(@as(u32, 31), insn & 0x1F);
    try testing.expectEqual(@as(u32, 12), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 13), (insn >> 16) & 0x1F);

    // Verify complete encoding: 0xEA0D019F (ANDS XZR, X12, X13 == TST X12, X13)
    try testing.expectEqual(@as(u32, 0xEA0D019F), insn);
}

test "emit tst rr 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v25 = root.reg.VReg.new(25, .int);
    const v30 = root.reg.VReg.new(30, .int);
    const r25 = Reg.fromVReg(v25);
    const r30 = Reg.fromVReg(v30);

    // TST W25, W30
    try emit(.{ .tst_rr = .{
        .src1 = r25,
        .src2 = r30,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x6A1E033F (ANDS WZR, W25, W30 == TST W25, W30)
    try testing.expectEqual(@as(u32, 0x6A1E033F), insn);
}

test "emit tst imm 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v4 = root.reg.VReg.new(4, .int);
    const r4 = Reg.fromVReg(v4);

    // TST X4, #0xff (alias for ANDS XZR, X4, #0xff)
    const imm_logic = root.aarch64_inst.ImmLogic{
        .value = 0xff,
        .n = true, // N=1 for 64-bit patterns
        .r = 0, // immr
        .s = 7, // imms (8 consecutive 1s)
        .size = .size64,
    };

    try emit(.{ .tst_imm = .{
        .src = r4,
        .imm = imm_logic,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 29-23) = 0b11100100 for ANDS immediate
    try testing.expectEqual(@as(u32, 0b11100100), (insn >> 23) & 0x7F);

    // Check N bit
    try testing.expectEqual(@as(u32, 1), (insn >> 22) & 1);

    // Check immr and imms fields
    try testing.expectEqual(@as(u32, 0), (insn >> 16) & 0x3F);
    try testing.expectEqual(@as(u32, 7), (insn >> 10) & 0x3F);

    // Check Rd = 31 (XZR), Rn = 4
    try testing.expectEqual(@as(u32, 31), insn & 0x1F);
    try testing.expectEqual(@as(u32, 4), (insn >> 5) & 0x1F);

    // Verify complete encoding: 0xF240109F (ANDS XZR, X4, #0xff == TST X4, #0xff)
    try testing.expectEqual(@as(u32, 0xF240109F), insn);
}

test "emit tst imm 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const r6 = Reg.fromVReg(v6);

    // TST W6, #0xf (test lower 4 bits)
    const imm_logic = root.aarch64_inst.ImmLogic{
        .value = 0xf,
        .n = false, // N=0 for 32-bit patterns
        .r = 0, // immr
        .s = 3, // imms (4 consecutive 1s)
        .size = .size32,
    };

    try emit(.{ .tst_imm = .{
        .src = r6,
        .imm = imm_logic,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check N bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 22) & 1);

    // Check immr = 0, imms = 3
    try testing.expectEqual(@as(u32, 0), (insn >> 16) & 0x3F);
    try testing.expectEqual(@as(u32, 3), (insn >> 10) & 0x3F);

    // Verify complete encoding: 0x72000CDF (ANDS WZR, W6, #0xf == TST W6, #0xf)
    try testing.expectEqual(@as(u32, 0x72000CDF), insn);
}

test "emit lsl register 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSLV X0, X1, X2
    try emit(.{ .lsl_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode field (bits 21-28) = 0b11010110
    try testing.expectEqual(@as(u32, 0b11010110), (insn >> 21) & 0xFF);

    // Check opcode2 field (bits 10-15) = 0b001000 for LSLV
    try testing.expectEqual(@as(u32, 0b001000), (insn >> 10) & 0x3F);

    // Check Rd = 0, Rn = 1, Rm = 2
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F);

    // Verify complete encoding: 0x9AC22020
    try testing.expectEqual(@as(u32, 0x9AC22020), insn);
}

test "emit lsl register 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSLV W0, W1, W2
    try emit(.{ .lsl_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x1AC22020
    try testing.expectEqual(@as(u32, 0x1AC22020), insn);
}

test "emit lsl immediate 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSL X0, X1, #5
    try emit(.{ .lsl_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 23-30) = 0b10100110
    try testing.expectEqual(@as(u32, 0b10100110), (insn >> 23) & 0xFF);

    // Check N bit (bit 22) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 22) & 1);

    // Verify complete encoding: 0xD37BEC20 (immr=59, imms=58)
    try testing.expectEqual(@as(u32, 0xD37BEC20), insn);
}

test "emit lsl immediate 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSL W0, W1, #5
    try emit(.{ .lsl_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 5,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x531B6C20 (immr=27, imms=26)
    try testing.expectEqual(@as(u32, 0x531B6C20), insn);
}

test "emit lsr register 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSRV X0, X1, X2
    try emit(.{ .lsr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode2 field (bits 10-15) = 0b001001 for LSRV
    try testing.expectEqual(@as(u32, 0b001001), (insn >> 10) & 0x3F);

    // Verify complete encoding: 0x9AC22420
    try testing.expectEqual(@as(u32, 0x9AC22420), insn);
}

test "emit lsr immediate 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSR X0, X1, #5
    try emit(.{ .lsr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Verify complete encoding: 0xD345FC20 (immr=5, imms=63)
    try testing.expectEqual(@as(u32, 0xD345FC20), insn);
}

test "emit asr register 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // ASRV X0, X1, X2
    try emit(.{ .asr_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode2 field (bits 10-15) = 0b001010 for ASRV
    try testing.expectEqual(@as(u32, 0b001010), (insn >> 10) & 0x3F);

    // Verify complete encoding: 0x9AC22820
    try testing.expectEqual(@as(u32, 0x9AC22820), insn);
}

test "emit asr immediate 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // ASR X0, X1, #5
    try emit(.{ .asr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 23-30) = 0b00100110 (SBFM)
    try testing.expectEqual(@as(u32, 0b00100110), (insn >> 23) & 0xFF);

    // Verify complete encoding: 0x9345FC20 (immr=5, imms=63)
    try testing.expectEqual(@as(u32, 0x9345FC20), insn);
}

test "emit ror register 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // RORV X0, X1, X2
    try emit(.{ .ror_rr = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode2 field (bits 10-15) = 0b001011 for RORV
    try testing.expectEqual(@as(u32, 0b001011), (insn >> 10) & 0x3F);

    // Verify complete encoding: 0x9AC22C20
    try testing.expectEqual(@as(u32, 0x9AC22C20), insn);
}

test "emit ror immediate 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // ROR X0, X1, #5
    try emit(.{ .ror_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 5,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 23-30) = 0b00100111 (EXTR)
    try testing.expectEqual(@as(u32, 0b00100111), (insn >> 23) & 0xFF);

    // Verify complete encoding: 0x93C11420 (Rm=Rn=1, imms=5)
    try testing.expectEqual(@as(u32, 0x93C11420), insn);
}

test "emit ror immediate 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // ROR W0, W1, #16
    try emit(.{ .ror_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 16,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify complete encoding: 0x13814020 (Rm=Rn=1, imms=16)
    try testing.expectEqual(@as(u32, 0x13814020), insn);
}

test "emit shift with edge cases" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LSL X0, X1, #0 (shift by 0)
    try emit(.{ .lsl_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 0,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    var insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // immr = (64 - 0) % 64 = 0, imms = 63
    try testing.expectEqual(@as(u32, 0xD340FC20), insn);

    buffer.data.clearRetainingCapacity();

    // LSR X0, X1, #63 (maximum shift for 64-bit)
    try emit(.{ .lsr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 63,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify encoding: immr=63, imms=63
    try testing.expectEqual(@as(u32, 0xD37FFC20), insn);

    buffer.data.clearRetainingCapacity();

    // LSR W0, W1, #31 (maximum shift for 32-bit)
    try emit(.{ .lsr_imm = .{
        .dst = wr0,
        .src = r1,
        .imm = 31,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify encoding: immr=31, imms=31
    try testing.expectEqual(@as(u32, 0x537F7C20), insn);
}

test "emit clz 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // CLZ X0, X1
    try emit(.{ .clz = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check fixed bits (bits 30-21) = 0b1011010110
    try testing.expectEqual(@as(u32, 0b1011010110), (insn >> 21) & 0x3FF);

    // Check opcode2 field (bits 16-20) = 0b00000
    try testing.expectEqual(@as(u32, 0b00000), (insn >> 16) & 0x1F);

    // Check opcode field (bits 10-15) = 0b00100
    try testing.expectEqual(@as(u32, 0b00100), (insn >> 10) & 0x3F);

    // Check Rn field (bits 5-9) = 1
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 0
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);

    // Verify complete encoding: 0xDAC01020
    try testing.expectEqual(@as(u32, 0xDAC01020), insn);
}

test "emit clz 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // CLZ W3, W5
    try emit(.{ .clz = .{
        .dst = wr3,
        .src = r5,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check fixed bits (bits 30-21) = 0b1011010110
    try testing.expectEqual(@as(u32, 0b1011010110), (insn >> 21) & 0x3FF);

    // Check opcode field (bits 10-15) = 0b00100
    try testing.expectEqual(@as(u32, 0b00100), (insn >> 10) & 0x3F);

    // Check Rn field (bits 5-9) = 5
    try testing.expectEqual(@as(u32, 5), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 3
    try testing.expectEqual(@as(u32, 3), insn & 0x1F);

    // Verify complete encoding: 0x5AC010A3
    try testing.expectEqual(@as(u32, 0x5AC010A3), insn);
}

test "emit cls 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v2 = root.reg.VReg.new(2, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const r2 = Reg.fromVReg(v2);
    const r7 = Reg.fromVReg(v7);
    const wr2 = root.reg.WritableReg.fromReg(r2);

    // CLS X2, X7
    try emit(.{ .cls = .{
        .dst = wr2,
        .src = r7,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check fixed bits (bits 30-21) = 0b1011010110
    try testing.expectEqual(@as(u32, 0b1011010110), (insn >> 21) & 0x3FF);

    // Check opcode2 field (bits 16-20) = 0b00000
    try testing.expectEqual(@as(u32, 0b00000), (insn >> 16) & 0x1F);

    // Check opcode field (bits 10-15) = 0b00101
    try testing.expectEqual(@as(u32, 0b00101), (insn >> 10) & 0x3F);

    // Check Rn field (bits 5-9) = 7
    try testing.expectEqual(@as(u32, 7), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 2
    try testing.expectEqual(@as(u32, 2), insn & 0x1F);

    // Verify complete encoding: 0xDAC014E2
    try testing.expectEqual(@as(u32, 0xDAC014E2), insn);
}

test "emit cls 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v15 = root.reg.VReg.new(15, .int);
    const r10 = Reg.fromVReg(v10);
    const r15 = Reg.fromVReg(v15);
    const wr10 = root.reg.WritableReg.fromReg(r10);

    // CLS W10, W15
    try emit(.{ .cls = .{
        .dst = wr10,
        .src = r15,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check fixed bits (bits 30-21) = 0b1011010110
    try testing.expectEqual(@as(u32, 0b1011010110), (insn >> 21) & 0x3FF);

    // Check opcode field (bits 10-15) = 0b00101
    try testing.expectEqual(@as(u32, 0b00101), (insn >> 10) & 0x3F);

    // Check Rn field (bits 5-9) = 15
    try testing.expectEqual(@as(u32, 15), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 10
    try testing.expectEqual(@as(u32, 10), insn & 0x1F);

    // Verify complete encoding: 0x5AC015EA
    try testing.expectEqual(@as(u32, 0x5AC015EA), insn);
}

test "emit rbit 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v4 = root.reg.VReg.new(4, .int);
    const v9 = root.reg.VReg.new(9, .int);
    const r4 = Reg.fromVReg(v4);
    const r9 = Reg.fromVReg(v9);
    const wr4 = root.reg.WritableReg.fromReg(r4);

    // RBIT X4, X9
    try emit(.{ .rbit = .{
        .dst = wr4,
        .src = r9,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check fixed bits (bits 30-21) = 0b1011010110
    try testing.expectEqual(@as(u32, 0b1011010110), (insn >> 21) & 0x3FF);

    // Check opcode2 field (bits 16-20) = 0b00000
    try testing.expectEqual(@as(u32, 0b00000), (insn >> 16) & 0x1F);

    // Check opcode field (bits 10-15) = 0b00000
    try testing.expectEqual(@as(u32, 0b00000), (insn >> 10) & 0x3F);

    // Check Rn field (bits 5-9) = 9
    try testing.expectEqual(@as(u32, 9), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 4
    try testing.expectEqual(@as(u32, 4), insn & 0x1F);

    // Verify complete encoding: 0xDAC00124
    try testing.expectEqual(@as(u32, 0xDAC00124), insn);
}

test "emit rbit 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v8 = root.reg.VReg.new(8, .int);
    const v12 = root.reg.VReg.new(12, .int);
    const r8 = Reg.fromVReg(v8);
    const r12 = Reg.fromVReg(v12);
    const wr8 = root.reg.WritableReg.fromReg(r8);

    // RBIT W8, W12
    try emit(.{ .rbit = .{
        .dst = wr8,
        .src = r12,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check fixed bits (bits 30-21) = 0b1011010110
    try testing.expectEqual(@as(u32, 0b1011010110), (insn >> 21) & 0x3FF);

    // Check opcode field (bits 10-15) = 0b00000
    try testing.expectEqual(@as(u32, 0b00000), (insn >> 10) & 0x3F);

    // Check Rn field (bits 5-9) = 12
    try testing.expectEqual(@as(u32, 12), (insn >> 5) & 0x1F);

    // Check Rd field (bits 0-4) = 8
    try testing.expectEqual(@as(u32, 8), insn & 0x1F);

    // Verify complete encoding: 0x5AC00188
    try testing.expectEqual(@as(u32, 0x5AC00188), insn);
}

test "emit bit manipulation with different registers" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // CLZ X0, X1
    try emit(.{ .clz = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    var insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check Rd = 0, Rn = 1
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);

    buffer.data.clearRetainingCapacity();

    // CLS X0, X1
    try emit(.{ .cls = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check Rd = 0, Rn = 1
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);

    buffer.data.clearRetainingCapacity();

    // RBIT X0, X1
    try emit(.{ .rbit = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check Rd = 0, Rn = 1
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);
}

test "emit csel 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // CSEL X0, X1, X2, EQ
    try emit(.{ .csel = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .cond = .eq,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Encoding: sf|0|0|11010100|Rm|cond|00|Rn|Rd
    // sf=1, Rm=2, cond=0000 (EQ), op=00, Rn=1, Rd=0
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 for 64-bit
    try testing.expectEqual(@as(u32, 0b00011010100), (insn >> 20) & 0x7FF); // opcode
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b0000), (insn >> 12) & 0xF); // cond=EQ
    try testing.expectEqual(@as(u32, 0b00), (insn >> 10) & 0x3); // op=00 for CSEL
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // Rd
}

test "emit csel 32-bit with different conditions" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const v12 = root.reg.VReg.new(12, .int);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const r12 = Reg.fromVReg(v12);
    const wr10 = root.reg.WritableReg.fromReg(r10);

    // CSEL W10, W11, W12, GT (greater than)
    try emit(.{ .csel = .{
        .dst = wr10,
        .src1 = r11,
        .src2 = r12,
        .cond = .gt,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // sf=0, Rm=12, cond=1100 (GT), op=00, Rn=11, Rd=10
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 for 32-bit
    try testing.expectEqual(@as(u32, 12), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b1100), (insn >> 12) & 0xF); // cond=GT
    try testing.expectEqual(@as(u32, 0b00), (insn >> 10) & 0x3); // op=00
    try testing.expectEqual(@as(u32, 11), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 10), insn & 0x1F); // Rd
}

test "emit csinc 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // CSINC X3, X4, X5, NE
    try emit(.{ .csinc = .{
        .dst = wr3,
        .src1 = r4,
        .src2 = r5,
        .cond = .ne,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Encoding: sf|0|0|11010100|Rm|cond|01|Rn|Rd
    // sf=1, Rm=5, cond=0001 (NE), op=01, Rn=4, Rd=3
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1
    try testing.expectEqual(@as(u32, 0b00011010100), (insn >> 20) & 0x7FF); // opcode
    try testing.expectEqual(@as(u32, 5), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b0001), (insn >> 12) & 0xF); // cond=NE
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0x3); // op=01 for CSINC
    try testing.expectEqual(@as(u32, 4), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 3), insn & 0x1F); // Rd
}

test "emit csinc 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const v21 = root.reg.VReg.new(21, .int);
    const v22 = root.reg.VReg.new(22, .int);
    const r20 = Reg.fromVReg(v20);
    const r21 = Reg.fromVReg(v21);
    const r22 = Reg.fromVReg(v22);
    const wr20 = root.reg.WritableReg.fromReg(r20);

    // CSINC W20, W21, W22, HS (higher or same, unsigned >=)
    try emit(.{ .csinc = .{
        .dst = wr20,
        .src1 = r21,
        .src2 = r22,
        .cond = .hs,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // sf=0, Rm=22, cond=0010 (HS), op=01, Rn=21, Rd=20
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 for 32-bit
    try testing.expectEqual(@as(u32, 22), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b0010), (insn >> 12) & 0xF); // cond=HS
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0x3); // op=01
    try testing.expectEqual(@as(u32, 21), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 20), insn & 0x1F); // Rd
}

test "emit csinv 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);
    const wr6 = root.reg.WritableReg.fromReg(r6);

    // CSINV X6, X7, X8, LT (signed less than)
    try emit(.{ .csinv = .{
        .dst = wr6,
        .src1 = r7,
        .src2 = r8,
        .cond = .lt,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Encoding: sf|1|0|11010100|Rm|cond|00|Rn|Rd
    // sf=1, Rm=8, cond=1011 (LT), op=00 (but bit 30=1), Rn=7, Rd=6
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1
    try testing.expectEqual(@as(u32, 0b10011010100), (insn >> 20) & 0x7FF); // opcode with bit 30=1
    try testing.expectEqual(@as(u32, 8), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b1011), (insn >> 12) & 0xF); // cond=LT
    try testing.expectEqual(@as(u32, 0b00), (insn >> 10) & 0x3); // op=00
    try testing.expectEqual(@as(u32, 7), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 6), insn & 0x1F); // Rd
}

test "emit csinv 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v15 = root.reg.VReg.new(15, .int);
    const v16 = root.reg.VReg.new(16, .int);
    const v17 = root.reg.VReg.new(17, .int);
    const r15 = Reg.fromVReg(v15);
    const r16 = Reg.fromVReg(v16);
    const r17 = Reg.fromVReg(v17);
    const wr15 = root.reg.WritableReg.fromReg(r15);

    // CSINV W15, W16, W17, GE (signed >=)
    try emit(.{ .csinv = .{
        .dst = wr15,
        .src1 = r16,
        .src2 = r17,
        .cond = .ge,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // sf=0, Rm=17, cond=1010 (GE), op=00 (bit 30=1), Rn=16, Rd=15
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 for 32-bit
    try testing.expectEqual(@as(u32, 17), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b1010), (insn >> 12) & 0xF); // cond=GE
    try testing.expectEqual(@as(u32, 0b00), (insn >> 10) & 0x3); // op=00
    try testing.expectEqual(@as(u32, 16), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 15), insn & 0x1F); // Rd
}

test "emit csneg 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v9 = root.reg.VReg.new(9, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const r9 = Reg.fromVReg(v9);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const wr9 = root.reg.WritableReg.fromReg(r9);

    // CSNEG X9, X10, X11, LE (signed <=)
    try emit(.{ .csneg = .{
        .dst = wr9,
        .src1 = r10,
        .src2 = r11,
        .cond = .le,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Encoding: sf|1|0|11010100|Rm|cond|01|Rn|Rd
    // sf=1, Rm=11, cond=1101 (LE), op=01 (bit 30=1), Rn=10, Rd=9
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1
    try testing.expectEqual(@as(u32, 0b10011010100), (insn >> 20) & 0x7FF); // opcode with bit 30=1
    try testing.expectEqual(@as(u32, 11), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b1101), (insn >> 12) & 0xF); // cond=LE
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0x3); // op=01 for CSNEG
    try testing.expectEqual(@as(u32, 10), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 9), insn & 0x1F); // Rd
}

test "emit csneg 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v25 = root.reg.VReg.new(25, .int);
    const v26 = root.reg.VReg.new(26, .int);
    const v27 = root.reg.VReg.new(27, .int);
    const r25 = Reg.fromVReg(v25);
    const r26 = Reg.fromVReg(v26);
    const r27 = Reg.fromVReg(v27);
    const wr25 = root.reg.WritableReg.fromReg(r25);

    // CSNEG W25, W26, W27, HI (unsigned >)
    try emit(.{ .csneg = .{
        .dst = wr25,
        .src1 = r26,
        .src2 = r27,
        .cond = .hi,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // sf=0, Rm=27, cond=1000 (HI), op=01 (bit 30=1), Rn=26, Rd=25
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 for 32-bit
    try testing.expectEqual(@as(u32, 27), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b1000), (insn >> 12) & 0xF); // cond=HI
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0x3); // op=01
    try testing.expectEqual(@as(u32, 26), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 25), insn & 0x1F); // Rd
}

test "emit conditional select with same registers" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const r5 = Reg.fromVReg(v5);
    const wr5 = root.reg.WritableReg.fromReg(r5);

    // CSEL X5, X5, X5, AL (always)
    try emit(.{ .csel = .{
        .dst = wr5,
        .src1 = r5,
        .src2 = r5,
        .cond = .al,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // All registers should be 5
    try testing.expectEqual(@as(u32, 5), insn & 0x1F); // Rd
    try testing.expectEqual(@as(u32, 5), (insn >> 5) & 0x1F); // Rn
    try testing.expectEqual(@as(u32, 5), (insn >> 16) & 0x1F); // Rm
    try testing.expectEqual(@as(u32, 0b1110), (insn >> 12) & 0xF); // cond=AL
}
test "emit movz 64-bit shift 0" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // MOVZ X0, #0x1234, lsl #0
    try emit(.{ .movz = .{
        .dst = wr0,
        .imm = 0x1234,
        .shift = 0,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit (bit 31) = 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opc (bits 29-30) = 0b10 for MOVZ
    try testing.expectEqual(@as(u32, 0b10), (insn >> 29) & 0x3);

    // Check opcode (bits 23-28) = 0b100101
    try testing.expectEqual(@as(u32, 0b100101), (insn >> 23) & 0x3F);

    // Check hw (bits 21-22) = 0 for shift 0
    try testing.expectEqual(@as(u32, 0), (insn >> 21) & 0x3);

    // Check immediate value (bits 5-20) = 0x1234
    try testing.expectEqual(@as(u32, 0x1234), (insn >> 5) & 0xFFFF);

    // Check Rd = 0
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);

    // Verify complete encoding: 0xD2824680 (MOVZ X0, #0x1234)
    try testing.expectEqual(@as(u32, 0xD2824680), insn);
}

test "emit movz 64-bit shift 16" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const r5 = Reg.fromVReg(v5);
    const wr5 = root.reg.WritableReg.fromReg(r5);

    // MOVZ X5, #0xABCD, lsl #16
    try emit(.{ .movz = .{
        .dst = wr5,
        .imm = 0xABCD,
        .shift = 16,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check hw = 1 for shift 16
    try testing.expectEqual(@as(u32, 1), (insn >> 21) & 0x3);
    try testing.expectEqual(@as(u32, 0xABCD), (insn >> 5) & 0xFFFF);
    try testing.expectEqual(@as(u32, 5), insn & 0x1F);
}

test "emit movz 64-bit shift 32" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const r10 = Reg.fromVReg(v10);
    const wr10 = root.reg.WritableReg.fromReg(r10);

    // MOVZ X10, #0x5678, lsl #32
    try emit(.{ .movz = .{
        .dst = wr10,
        .imm = 0x5678,
        .shift = 32,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check hw = 2 for shift 32
    try testing.expectEqual(@as(u32, 2), (insn >> 21) & 0x3);
    try testing.expectEqual(@as(u32, 0x5678), (insn >> 5) & 0xFFFF);
    try testing.expectEqual(@as(u32, 10), insn & 0x1F);
}

test "emit movz 64-bit shift 48" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v15 = root.reg.VReg.new(15, .int);
    const r15 = Reg.fromVReg(v15);
    const wr15 = root.reg.WritableReg.fromReg(r15);

    // MOVZ X15, #0x1111, lsl #48
    try emit(.{ .movz = .{
        .dst = wr15,
        .imm = 0x1111,
        .shift = 48,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check hw = 3 for shift 48
    try testing.expectEqual(@as(u32, 3), (insn >> 21) & 0x3);
    try testing.expectEqual(@as(u32, 0x1111), (insn >> 5) & 0xFFFF);
    try testing.expectEqual(@as(u32, 15), insn & 0x1F);
}

test "emit movz 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const r20 = Reg.fromVReg(v20);
    const wr20 = root.reg.WritableReg.fromReg(r20);

    // MOVZ W20, #0x9999, lsl #0
    try emit(.{ .movz = .{
        .dst = wr20,
        .imm = 0x9999,
        .shift = 0,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);
    try testing.expectEqual(@as(u32, 0), (insn >> 21) & 0x3);
    try testing.expectEqual(@as(u32, 0x9999), (insn >> 5) & 0xFFFF);
    try testing.expectEqual(@as(u32, 20), insn & 0x1F);
}

test "emit movz 32-bit shift 16" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v7 = root.reg.VReg.new(7, .int);
    const r7 = Reg.fromVReg(v7);
    const wr7 = root.reg.WritableReg.fromReg(r7);

    // MOVZ W7, #0x4321, lsl #16
    try emit(.{ .movz = .{
        .dst = wr7,
        .imm = 0x4321,
        .shift = 16,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 0, hw = 1
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);
    try testing.expectEqual(@as(u32, 1), (insn >> 21) & 0x3);
    try testing.expectEqual(@as(u32, 0x4321), (insn >> 5) & 0xFFFF);
    try testing.expectEqual(@as(u32, 7), insn & 0x1F);
}

test "emit movk 64-bit shift 0" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v1 = root.reg.VReg.new(1, .int);
    const r1 = Reg.fromVReg(v1);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    // MOVK X1, #0x5678, lsl #0
    try emit(.{ .movk = .{
        .dst = wr1,
        .imm = 0x5678,
        .shift = 0,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check sf bit = 1, opc = 0b11 for MOVK
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);
    try testing.expectEqual(@as(u32, 0b11), (insn >> 29) & 0x3);
    try testing.expectEqual(@as(u32, 0b100101), (insn >> 23) & 0x3F);
    try testing.expectEqual(@as(u32, 0), (insn >> 21) & 0x3);
    try testing.expectEqual(@as(u32, 0x5678), (insn >> 5) & 0xFFFF);
    try testing.expectEqual(@as(u32, 1), insn & 0x1F);
}

test "emit movk 64-bit all shifts" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v2 = root.reg.VReg.new(2, .int);
    const r2 = Reg.fromVReg(v2);
    const wr2 = root.reg.WritableReg.fromReg(r2);

    // Test shift 16
    try emit(.{ .movk = .{ .dst = wr2, .imm = 0xFFFF, .shift = 16, .size = .size64 } }, &buffer);
    var insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 1), (insn >> 21) & 0x3);

    buffer.data.clearRetainingCapacity();

    // Test shift 32
    const v3 = root.reg.VReg.new(3, .int);
    const r3 = Reg.fromVReg(v3);
    const wr3 = root.reg.WritableReg.fromReg(r3);
    try emit(.{ .movk = .{ .dst = wr3, .imm = 0x1234, .shift = 32, .size = .size64 } }, &buffer);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 2), (insn >> 21) & 0x3);

    buffer.data.clearRetainingCapacity();

    // Test shift 48
    const v4 = root.reg.VReg.new(4, .int);
    const r4 = Reg.fromVReg(v4);
    const wr4 = root.reg.WritableReg.fromReg(r4);
    try emit(.{ .movk = .{ .dst = wr4, .imm = 0xABCD, .shift = 48, .size = .size64 } }, &buffer);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 3), (insn >> 21) & 0x3);
}

test "emit movk 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v25 = root.reg.VReg.new(25, .int);
    const r25 = Reg.fromVReg(v25);
    const wr25 = root.reg.WritableReg.fromReg(r25);

    // MOVK W25, #0x8888, lsl #0
    try emit(.{ .movk = .{ .dst = wr25, .imm = 0x8888, .shift = 0, .size = .size32 } }, &buffer);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);
    try testing.expectEqual(@as(u32, 0), (insn >> 21) & 0x3);

    buffer.data.clearRetainingCapacity();

    // Test shift 16
    const v30 = root.reg.VReg.new(30, .int);
    const r30 = Reg.fromVReg(v30);
    const wr30 = root.reg.WritableReg.fromReg(r30);
    try emit(.{ .movk = .{ .dst = wr30, .imm = 0x2222, .shift = 16, .size = .size32 } }, &buffer);
    const insn2 = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 1), (insn2 >> 21) & 0x3);
}

test "emit movn 64-bit all shifts" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v8 = root.reg.VReg.new(8, .int);
    const r8 = Reg.fromVReg(v8);
    const wr8 = root.reg.WritableReg.fromReg(r8);

    // Test shift 0
    try emit(.{ .movn = .{ .dst = wr8, .imm = 0x1234, .shift = 0, .size = .size64 } }, &buffer);
    var insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1
    try testing.expectEqual(@as(u32, 0b00), (insn >> 29) & 0x3); // opc=00 for MOVN
    try testing.expectEqual(@as(u32, 0), (insn >> 21) & 0x3); // hw=0

    buffer.data.clearRetainingCapacity();

    // Test shift 16, 32, 48
    const shifts = [_]u8{ 16, 32, 48 };
    const expected_hw = [_]u32{ 1, 2, 3 };
    const regs = [_]u8{ 9, 11, 12 };

    for (shifts, expected_hw, regs) |shift, hw, reg| {
        const v = root.reg.VReg.new(reg, .int);
        const r = Reg.fromVReg(v);
        const wr = root.reg.WritableReg.fromReg(r);
        try emit(.{ .movn = .{ .dst = wr, .imm = 0x5678, .shift = shift, .size = .size64 } }, &buffer);
        insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
        try testing.expectEqual(hw, (insn >> 21) & 0x3);
        buffer.data.clearRetainingCapacity();
    }
}

test "emit movn 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v13 = root.reg.VReg.new(13, .int);
    const r13 = Reg.fromVReg(v13);
    const wr13 = root.reg.WritableReg.fromReg(r13);

    // Test shift 0
    try emit(.{ .movn = .{ .dst = wr13, .imm = 0x7777, .shift = 0, .size = .size32 } }, &buffer);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0
    try testing.expectEqual(@as(u32, 0), (insn >> 21) & 0x3); // hw=0

    buffer.data.clearRetainingCapacity();

    // Test shift 16
    const v14 = root.reg.VReg.new(14, .int);
    const r14 = Reg.fromVReg(v14);
    const wr14 = root.reg.WritableReg.fromReg(r14);
    try emit(.{ .movn = .{ .dst = wr14, .imm = 0x1111, .shift = 16, .size = .size32 } }, &buffer);
    const insn2 = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 1), (insn2 >> 21) & 0x3); // hw=1
}

test "emit stp 64-bit zero offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    // STP X0, X1, [X2, #0]
    try emit(.{ .stp = .{
        .src1 = r0,
        .src2 = r1,
        .base = r2,
        .offset = 0,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding: sf|10|1|0|010|0|imm7|Rt2|Rn|Rt
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 (64-bit)
    try testing.expectEqual(@as(u32, 0b1010010), (insn >> 23) & 0x7F); // opc|V|mode
    try testing.expectEqual(@as(u32, 0), (insn >> 15) & 0x7F); // imm7=0
    try testing.expectEqual(@as(u32, 1), (insn >> 10) & 0x1F); // Rt2=X1
    try testing.expectEqual(@as(u32, 2), (insn >> 5) & 0x1F); // Rn=X2
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // Rt=X0
}

test "emit stp 64-bit positive offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const v12 = root.reg.VReg.new(12, .int);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const r12 = Reg.fromVReg(v12);

    // STP X10, X11, [X12, #16]
    // Offset 16 bytes = 2 * 8 bytes, so imm7 = 2
    try emit(.{ .stp = .{
        .src1 = r10,
        .src2 = r11,
        .base = r12,
        .offset = 16,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 (64-bit)
    try testing.expectEqual(@as(u32, 2), (insn >> 15) & 0x7F); // imm7=2 (16/8)
    try testing.expectEqual(@as(u32, 11), (insn >> 10) & 0x1F); // Rt2=X11
    try testing.expectEqual(@as(u32, 12), (insn >> 5) & 0x1F); // Rn=X12
    try testing.expectEqual(@as(u32, 10), insn & 0x1F); // Rt=X10
}

test "emit stp 64-bit negative offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const v21 = root.reg.VReg.new(21, .int);
    const v22 = root.reg.VReg.new(22, .int);
    const r20 = Reg.fromVReg(v20);
    const r21 = Reg.fromVReg(v21);
    const r22 = Reg.fromVReg(v22);

    // STP X20, X21, [X22, #-16]
    // Offset -16 bytes = -2 * 8 bytes, so imm7 = -2 (0x7E in 7-bit two's complement)
    try emit(.{ .stp = .{
        .src1 = r20,
        .src2 = r21,
        .base = r22,
        .offset = -16,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 (64-bit)
    try testing.expectEqual(@as(u32, 0x7E), (insn >> 15) & 0x7F); // imm7=-2
    try testing.expectEqual(@as(u32, 21), (insn >> 10) & 0x1F); // Rt2=X21
    try testing.expectEqual(@as(u32, 22), (insn >> 5) & 0x1F); // Rn=X22
    try testing.expectEqual(@as(u32, 20), insn & 0x1F); // Rt=X20
}

test "emit stp 32-bit zero offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);

    // STP W3, W4, [X5, #0]
    try emit(.{ .stp = .{
        .src1 = r3,
        .src2 = r4,
        .base = r5,
        .offset = 0,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding: sf|10|1|0|010|0|imm7|Rt2|Rn|Rt
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 (32-bit)
    try testing.expectEqual(@as(u32, 0b1010010), (insn >> 23) & 0x7F); // opc|V|mode
    try testing.expectEqual(@as(u32, 0), (insn >> 15) & 0x7F); // imm7=0
    try testing.expectEqual(@as(u32, 4), (insn >> 10) & 0x1F); // Rt2=W4
    try testing.expectEqual(@as(u32, 5), (insn >> 5) & 0x1F); // Rn=X5
    try testing.expectEqual(@as(u32, 3), insn & 0x1F); // Rt=W3
}

test "emit stp 32-bit with offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);

    // STP W6, W7, [X8, #8]
    // For 32-bit, offset is scaled by 4, so 8 bytes = imm7 of 2
    try emit(.{ .stp = .{
        .src1 = r6,
        .src2 = r7,
        .base = r8,
        .offset = 8,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 (32-bit)
    // For 32-bit, offset is divided by 4 (size of 32-bit register pair element)
    try testing.expectEqual(@as(u32, 2), (insn >> 15) & 0x7F); // imm7=2 (8/4)
    try testing.expectEqual(@as(u32, 7), (insn >> 10) & 0x1F); // Rt2=W7
    try testing.expectEqual(@as(u32, 8), (insn >> 5) & 0x1F); // Rn=X8
    try testing.expectEqual(@as(u32, 6), insn & 0x1F); // Rt=W6
}

test "emit ldp 64-bit zero offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    // LDP X0, X1, [X2, #0]
    try emit(.{ .ldp = .{
        .dst1 = wr0,
        .dst2 = wr1,
        .base = r2,
        .offset = 0,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding: sf|10|1|0|011|0|imm7|Rt2|Rn|Rt
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 (64-bit)
    try testing.expectEqual(@as(u32, 0b1010011), (insn >> 23) & 0x7F); // opc|V|mode (note: bit 22 is 1 for LDP)
    try testing.expectEqual(@as(u32, 0), (insn >> 15) & 0x7F); // imm7=0
    try testing.expectEqual(@as(u32, 1), (insn >> 10) & 0x1F); // Rt2=X1
    try testing.expectEqual(@as(u32, 2), (insn >> 5) & 0x1F); // Rn=X2
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // Rt=X0
}

test "emit ldp 64-bit positive offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const v12 = root.reg.VReg.new(12, .int);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const r12 = Reg.fromVReg(v12);
    const wr10 = root.reg.WritableReg.fromReg(r10);
    const wr11 = root.reg.WritableReg.fromReg(r11);

    // LDP X10, X11, [X12, #32]
    // Offset 32 bytes = 4 * 8 bytes, so imm7 = 4
    try emit(.{ .ldp = .{
        .dst1 = wr10,
        .dst2 = wr11,
        .base = r12,
        .offset = 32,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 (64-bit)
    try testing.expectEqual(@as(u32, 4), (insn >> 15) & 0x7F); // imm7=4 (32/8)
    try testing.expectEqual(@as(u32, 11), (insn >> 10) & 0x1F); // Rt2=X11
    try testing.expectEqual(@as(u32, 12), (insn >> 5) & 0x1F); // Rn=X12
    try testing.expectEqual(@as(u32, 10), insn & 0x1F); // Rt=X10
}

test "emit ldp 64-bit negative offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const v21 = root.reg.VReg.new(21, .int);
    const v22 = root.reg.VReg.new(22, .int);
    const r20 = Reg.fromVReg(v20);
    const r21 = Reg.fromVReg(v21);
    const r22 = Reg.fromVReg(v22);
    const wr20 = root.reg.WritableReg.fromReg(r20);
    const wr21 = root.reg.WritableReg.fromReg(r21);

    // LDP X20, X21, [X22, #-24]
    // Offset -24 bytes = -3 * 8 bytes, so imm7 = -3 (0x7D in 7-bit two's complement)
    try emit(.{ .ldp = .{
        .dst1 = wr20,
        .dst2 = wr21,
        .base = r22,
        .offset = -24,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf=1 (64-bit)
    try testing.expectEqual(@as(u32, 0x7D), (insn >> 15) & 0x7F); // imm7=-3
    try testing.expectEqual(@as(u32, 21), (insn >> 10) & 0x1F); // Rt2=X21
    try testing.expectEqual(@as(u32, 22), (insn >> 5) & 0x1F); // Rn=X22
    try testing.expectEqual(@as(u32, 20), insn & 0x1F); // Rt=X20
}

test "emit ldp 32-bit zero offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);
    const wr4 = root.reg.WritableReg.fromReg(r4);

    // LDP W3, W4, [X5, #0]
    try emit(.{ .ldp = .{
        .dst1 = wr3,
        .dst2 = wr4,
        .base = r5,
        .offset = 0,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 (32-bit)
    try testing.expectEqual(@as(u32, 0b1010011), (insn >> 23) & 0x7F); // opc|V|mode
    try testing.expectEqual(@as(u32, 0), (insn >> 15) & 0x7F); // imm7=0
    try testing.expectEqual(@as(u32, 4), (insn >> 10) & 0x1F); // Rt2=W4
    try testing.expectEqual(@as(u32, 5), (insn >> 5) & 0x1F); // Rn=X5
    try testing.expectEqual(@as(u32, 3), insn & 0x1F); // Rt=W3
}

test "emit ldp 32-bit with offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);
    const wr6 = root.reg.WritableReg.fromReg(r6);
    const wr7 = root.reg.WritableReg.fromReg(r7);

    // LDP W6, W7, [X8, #16]
    // For 32-bit, offset is scaled by 4, so 16 bytes = imm7 of 4
    try emit(.{ .ldp = .{
        .dst1 = wr6,
        .dst2 = wr7,
        .base = r8,
        .offset = 16,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check encoding
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1); // sf=0 (32-bit)
    // For 32-bit, offset is divided by 4 (size of 32-bit register pair element)
    try testing.expectEqual(@as(u32, 4), (insn >> 15) & 0x7F); // imm7=4 (16/4)
    try testing.expectEqual(@as(u32, 7), (insn >> 10) & 0x1F); // Rt2=W7
    try testing.expectEqual(@as(u32, 8), (insn >> 5) & 0x1F); // Rn=X8
    try testing.expectEqual(@as(u32, 6), insn & 0x1F); // Rt=W6
}

test "emit ldp and stp with max positive offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    // Max positive offset for 7-bit signed: 63 * 8 = 504 bytes
    try emit(.{ .stp = .{
        .src1 = r0,
        .src2 = r1,
        .base = r2,
        .offset = 504,
        .size = .size64,
    } }, &buffer);

    const insn1 = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 63), (insn1 >> 15) & 0x7F); // imm7=63

    buffer.data.clearRetainingCapacity();

    // Test LDP with same offset
    try emit(.{ .ldp = .{
        .dst1 = wr0,
        .dst2 = wr1,
        .base = r2,
        .offset = 504,
        .size = .size64,
    } }, &buffer);

    const insn2 = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 63), (insn2 >> 15) & 0x7F); // imm7=63
}

test "emit ldp and stp with max negative offset" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);
    const wr1 = root.reg.WritableReg.fromReg(r1);

    // Max negative offset for 7-bit signed: -64 * 8 = -512 bytes
    try emit(.{ .stp = .{
        .src1 = r0,
        .src2 = r1,
        .base = r2,
        .offset = -512,
        .size = .size64,
    } }, &buffer);

    const insn1 = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x40), (insn1 >> 15) & 0x7F); // imm7=-64 (0x40 in 7-bit)

    buffer.data.clearRetainingCapacity();

    // Test LDP with same offset
    try emit(.{ .ldp = .{
        .dst1 = wr0,
        .dst2 = wr1,
        .base = r2,
        .offset = -512,
        .size = .size64,
    } }, &buffer);

    const insn2 = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x40), (insn2 >> 15) & 0x7F); // imm7=-64
}

test "emit br" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const r5 = Reg.fromVReg(v5);

    // BR X5
    try emit(.{ .br = .{ .target = r5 } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Expected encoding: 0xd61f00a0 for BR X5
    try testing.expectEqual(@as(u32, 0xd61f00a0), insn);

    // Verify bit fields
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F); // op bits
    try testing.expectEqual(@as(u32, 0b00), (insn >> 21) & 0x3); // opc for BR
    try testing.expectEqual(@as(u32, 5), (insn >> 5) & 0x1F); // Rn=X5
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // Rm=0
}

test "emit br multiple registers" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Test BR with different registers
    const registers = [_]u5{ 0, 1, 10, 15, 30 };
    for (registers) |reg_idx| {
        buffer.data.clearRetainingCapacity();

        const vreg = root.reg.VReg.new(reg_idx, .int);
        const reg = Reg.fromVReg(vreg);

        try emit(.{ .br = .{ .target = reg } }, &buffer);

        try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
        const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

        // Verify register encoding
        try testing.expectEqual(@as(u32, reg_idx), (insn >> 5) & 0x1F);
        // Verify opcode
        try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F);
        try testing.expectEqual(@as(u32, 0b00), (insn >> 21) & 0x3);
    }
}

test "emit blr" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const r5 = Reg.fromVReg(v5);

    // BLR X5
    try emit(.{ .blr = .{ .target = r5 } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Expected encoding: 0xd63f00a0 for BLR X5
    try testing.expectEqual(@as(u32, 0xd63f00a0), insn);

    // Verify bit fields
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F); // op bits
    try testing.expectEqual(@as(u32, 0b01), (insn >> 21) & 0x3); // opc for BLR
    try testing.expectEqual(@as(u32, 5), (insn >> 5) & 0x1F); // Rn=X5
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // Rm=0
}

test "emit blr multiple registers" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Test BLR with different registers
    const registers = [_]u5{ 0, 1, 10, 15, 30 };
    for (registers) |reg_idx| {
        buffer.data.clearRetainingCapacity();

        const vreg = root.reg.VReg.new(reg_idx, .int);
        const reg = Reg.fromVReg(vreg);

        try emit(.{ .blr = .{ .target = reg } }, &buffer);

        try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
        const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

        // Verify register encoding
        try testing.expectEqual(@as(u32, reg_idx), (insn >> 5) & 0x1F);
        // Verify opcode
        try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F);
        try testing.expectEqual(@as(u32, 0b01), (insn >> 21) & 0x3);
    }
}

test "emit bl indirect via CallTarget" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const r10 = Reg.fromVReg(v10);

    // BL with indirect target (should emit BLR)
    const target = root.aarch64_inst.CallTarget{ .indirect = r10 };
    try emit(.{ .bl = .{ .target = target } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Should emit BLR X10: 0xd63f0140
    try testing.expectEqual(@as(u32, 0xd63f0140), insn);

    // Verify it's BLR encoding
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F);
    try testing.expectEqual(@as(u32, 0b01), (insn >> 21) & 0x3); // BLR opcode
    try testing.expectEqual(@as(u32, 10), (insn >> 5) & 0x1F); // Rn=X10
}

test "emit ret with default register" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // RET (defaults to X30)
    try emit(.{ .ret = .{ .reg = null } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Expected encoding: 0xd65f03c0 for RET (X30)
    try testing.expectEqual(@as(u32, 0xd65f03c0), insn);

    // Verify bit fields
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F);
    try testing.expectEqual(@as(u32, 0b10), (insn >> 21) & 0x3); // opc for RET
    try testing.expectEqual(@as(u32, 30), (insn >> 5) & 0x1F); // Rn=X30
}

test "emit ret with explicit register" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v15 = root.reg.VReg.new(15, .int);
    const r15 = Reg.fromVReg(v15);

    // RET X15
    try emit(.{ .ret = .{ .reg = r15 } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify bit fields
    try testing.expectEqual(@as(u32, 0b1101011), (insn >> 25) & 0x7F);
    try testing.expectEqual(@as(u32, 0b10), (insn >> 21) & 0x3); // opc for RET
    try testing.expectEqual(@as(u32, 15), (insn >> 5) & 0x1F); // Rn=X15
}

test "cmp is alias for subs with xzr" {
    // Verify that CMP produces the exact same encoding as SUBS with XZR destination
    var buffer1 = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer1.deinit();
    var buffer2 = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer2.deinit();

    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    // Emit CMP X1, X2
    try emit(.{ .cmp_rr = .{
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer1);

    // Emit SUBS XZR, X1, X2
    const xzr = Reg.fromPReg(root.reg.PReg.xzr);
    const wxzr = root.reg.WritableReg.fromReg(xzr);
    try emit(.{ .subs_rr = .{
        .dst = wxzr,
        .src1 = r1,
        .src2 = r2,
        .size = .size64,
    } }, &buffer2);

    // Both should produce identical encodings
    try testing.expectEqual(@as(usize, 4), buffer1.data.items.len);
    try testing.expectEqual(@as(usize, 4), buffer2.data.items.len);
    const insn1 = std.mem.bytesToValue(u32, buffer1.data.items[0..4]);
    const insn2 = std.mem.bytesToValue(u32, buffer2.data.items[0..4]);
    try testing.expectEqual(insn1, insn2);
}

test "emit ldr_reg 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LDR X0, [X1, X2]
    try emit(.{ .ldr_reg = .{
        .dst = wr0,
        .base = r1,
        .offset = r2,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf|111|0|00|01|Rm|011|0|10|Rn|Rt
    // sf=1, Rm=2, option=011, S=0, Rn=1, Rt=0
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100001 << 21) | (2 << 16) | (0b011010 << 10) | (1 << 5) | 0;
    try testing.expectEqual(expected, insn);
}

test "emit ldr_reg 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v15 = root.reg.VReg.new(15, .int);
    const r5 = Reg.fromVReg(v5);
    const r10 = Reg.fromVReg(v10);
    const r15 = Reg.fromVReg(v15);
    const wr5 = root.reg.WritableReg.fromReg(r5);

    // LDR W5, [X10, X15]
    try emit(.{ .ldr_reg = .{
        .dst = wr5,
        .base = r10,
        .offset = r15,
        .size = .size32,
    } }, &buffer);

    // Verify encoding: sf=0, Rm=15, option=011, S=0, Rn=10, Rt=5
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (0 << 31) | (0b11100001 << 21) | (15 << 16) | (0b011010 << 10) | (10 << 5) | 5;
    try testing.expectEqual(expected, insn);
}

test "emit ldr_ext sxtw 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LDR X0, [X1, W2, SXTW]
    try emit(.{ .ldr_ext = .{
        .dst = wr0,
        .base = r1,
        .offset = r2,
        .extend = .sxtw,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=2, option=110 (SXTW), S=0, Rn=1, Rt=0
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100001 << 21) | (2 << 16) | (0b110 << 13) | (0b010 << 10) | (1 << 5) | 0;
    try testing.expectEqual(expected, insn);
}

test "emit ldr_ext uxtw 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // LDR X3, [X4, W5, UXTW]
    try emit(.{ .ldr_ext = .{
        .dst = wr3,
        .base = r4,
        .offset = r5,
        .extend = .uxtw,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=5, option=010 (UXTW), S=0, Rn=4, Rt=3
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100001 << 21) | (5 << 16) | (0b010 << 13) | (0b010 << 10) | (4 << 5) | 3;
    try testing.expectEqual(expected, insn);
}

test "emit ldr_shifted 64-bit with LSL" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LDR X0, [X1, X2, LSL #3]
    try emit(.{ .ldr_shifted = .{
        .dst = wr0,
        .base = r1,
        .offset = r2,
        .shift_op = .lsl,
        .shift_amt = 3,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=2, option=011 (LSL), S=1 (scaled), Rn=1, Rt=0
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100001 << 21) | (2 << 16) | (0b011 << 13) | (1 << 12) | (0b10 << 10) | (1 << 5) | 0;
    try testing.expectEqual(expected, insn);
}

test "emit ldr_shifted 32-bit with LSL" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);
    const wr6 = root.reg.WritableReg.fromReg(r6);

    // LDR W6, [X7, X8, LSL #2]
    try emit(.{ .ldr_shifted = .{
        .dst = wr6,
        .base = r7,
        .offset = r8,
        .shift_op = .lsl,
        .shift_amt = 2,
        .size = .size32,
    } }, &buffer);

    // Verify encoding: sf=0, Rm=8, option=011 (LSL), S=1 (scaled), Rn=7, Rt=6
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (0 << 31) | (0b11100001 << 21) | (8 << 16) | (0b011 << 13) | (1 << 12) | (0b10 << 10) | (7 << 5) | 6;
    try testing.expectEqual(expected, insn);
}

test "emit str_reg 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    // STR X0, [X1, X2]
    try emit(.{ .str_reg = .{
        .src = r0,
        .base = r1,
        .offset = r2,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf|111|0|00|00|Rm|011|0|10|Rn|Rt
    // sf=1, Rm=2, option=011, S=0, Rn=1, Rt=0
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100000 << 21) | (2 << 16) | (0b011010 << 10) | (1 << 5) | 0;
    try testing.expectEqual(expected, insn);
}

test "emit str_reg 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v20 = root.reg.VReg.new(20, .int);
    const v30 = root.reg.VReg.new(30, .int);
    const r10 = Reg.fromVReg(v10);
    const r20 = Reg.fromVReg(v20);
    const r30 = Reg.fromVReg(v30);

    // STR W10, [X20, X30]
    try emit(.{ .str_reg = .{
        .src = r10,
        .base = r20,
        .offset = r30,
        .size = .size32,
    } }, &buffer);

    // Verify encoding: sf=0, Rm=30, option=011, S=0, Rn=20, Rt=10
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (0 << 31) | (0b11100000 << 21) | (30 << 16) | (0b011010 << 10) | (20 << 5) | 10;
    try testing.expectEqual(expected, insn);
}

test "emit str_ext sxtw 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);

    // STR X3, [X4, W5, SXTW]
    try emit(.{ .str_ext = .{
        .src = r3,
        .base = r4,
        .offset = r5,
        .extend = .sxtw,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=5, option=110 (SXTW), S=0, Rn=4, Rt=3
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100000 << 21) | (5 << 16) | (0b110 << 13) | (0b010 << 10) | (4 << 5) | 3;
    try testing.expectEqual(expected, insn);
}

test "emit str_ext uxtw 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const v8 = root.reg.VReg.new(8, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);

    // STR X6, [X7, W8, UXTW]
    try emit(.{ .str_ext = .{
        .src = r6,
        .base = r7,
        .offset = r8,
        .extend = .uxtw,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=8, option=010 (UXTW), S=0, Rn=7, Rt=6
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100000 << 21) | (8 << 16) | (0b010 << 13) | (0b010 << 10) | (7 << 5) | 6;
    try testing.expectEqual(expected, insn);
}

test "emit str_shifted 64-bit with LSL" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v9 = root.reg.VReg.new(9, .int);
    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const r9 = Reg.fromVReg(v9);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);

    // STR X9, [X10, X11, LSL #3]
    try emit(.{ .str_shifted = .{
        .src = r9,
        .base = r10,
        .offset = r11,
        .shift_op = .lsl,
        .shift_amt = 3,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=11, option=011, S=1 (scaled), Rn=10, Rt=9
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100000 << 21) | (11 << 16) | (0b011 << 13) | (1 << 12) | (0b10 << 10) | (10 << 5) | 9;
    try testing.expectEqual(expected, insn);
}

test "emit str_shifted 32-bit with LSL" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v12 = root.reg.VReg.new(12, .int);
    const v13 = root.reg.VReg.new(13, .int);
    const v14 = root.reg.VReg.new(14, .int);
    const r12 = Reg.fromVReg(v12);
    const r13 = Reg.fromVReg(v13);
    const r14 = Reg.fromVReg(v14);

    // STR W12, [X13, X14, LSL #2]
    try emit(.{ .str_shifted = .{
        .src = r12,
        .base = r13,
        .offset = r14,
        .shift_op = .lsl,
        .shift_amt = 2,
        .size = .size32,
    } }, &buffer);

    // Verify encoding: sf=0, Rm=14, option=011, S=1 (scaled), Rn=13, Rt=12
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (0 << 31) | (0b11100000 << 21) | (14 << 16) | (0b011 << 13) | (1 << 12) | (0b10 << 10) | (13 << 5) | 12;
    try testing.expectEqual(expected, insn);
}

test "emit ldr/str all extend modes" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // Test all extend types
    const extend_types = [_]Inst.ExtendOp{ .uxtb, .uxth, .uxtw, .uxtx, .sxtb, .sxth, .sxtw, .sxtx };

    for (extend_types) |ext| {
        buffer.data.clearRetainingCapacity();

        try emit(.{ .ldr_ext = .{
            .dst = wr0,
            .base = r1,
            .offset = r2,
            .extend = ext,
            .size = .size64,
        } }, &buffer);

        try testing.expectEqual(@as(usize, 4), buffer.data.items.len);

        buffer.data.clearRetainingCapacity();

        try emit(.{ .str_ext = .{
            .src = r0,
            .base = r1,
            .offset = r2,
            .extend = ext,
            .size = .size64,
        } }, &buffer);

        try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    }
}

test "cmn is alias for adds with xzr" {
    // Verify that CMN produces the exact same encoding as ADDS with XZR destination
    var buffer1 = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer1.deinit();
    var buffer2 = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer2.deinit();

    const v3 = root.reg.VReg.new(3, .int);
    const v4 = root.reg.VReg.new(4, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);

    // Emit CMN X3, X4
    try emit(.{ .cmn_rr = .{
        .src1 = r3,
        .src2 = r4,
        .size = .size64,
    } }, &buffer1);

    // Emit ADDS XZR, X3, X4
    const xzr = Reg.fromPReg(root.reg.PReg.xzr);
    const wxzr = root.reg.WritableReg.fromReg(xzr);
    try emit(.{ .adds_rr = .{
        .dst = wxzr,
        .src1 = r3,
        .src2 = r4,
        .size = .size64,
    } }, &buffer2);

    // Both should produce identical encodings
    try testing.expectEqual(@as(usize, 4), buffer1.data.items.len);
    try testing.expectEqual(@as(usize, 4), buffer2.data.items.len);
    const insn1 = std.mem.bytesToValue(u32, buffer1.data.items[0..4]);
    const insn2 = std.mem.bytesToValue(u32, buffer2.data.items[0..4]);
    try testing.expectEqual(insn1, insn2);
}

test "emit ldarb - verify correct encoding" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LDARB W0, [X1] - encoding: 0x08dffc20
    try emit(.{ .ldarb = .{
        .dst = wr0,
        .base = r1,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x08dffc20), insn);
}

test "emit ldarh - verify correct encoding" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v2 = root.reg.VReg.new(2, .int);
    const v3 = root.reg.VReg.new(3, .int);
    const r2 = Reg.fromVReg(v2);
    const r3 = Reg.fromVReg(v3);
    const wr2 = root.reg.WritableReg.fromReg(r2);

    // LDARH W2, [X3] - encoding: 0x48dffc62
    try emit(.{ .ldarh = .{
        .dst = wr2,
        .base = r3,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x48dffc62), insn);
}

test "emit ldar_w - verify correct encoding" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr4 = root.reg.WritableReg.fromReg(r4);

    // LDAR W4, [X5] - encoding: 0x88dffca4
    try emit(.{ .ldar_w = .{
        .dst = wr4,
        .base = r5,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x88dffca4), insn);
}

test "emit ldar_x - verify correct encoding" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const wr6 = root.reg.WritableReg.fromReg(r6);

    // LDAR X6, [X7] - encoding: 0xc8dffce6
    try emit(.{ .ldar_x = .{
        .dst = wr6,
        .base = r7,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0xc8dffce6), insn);
}

test "emit stlrb - verify correct encoding" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v8 = root.reg.VReg.new(8, .int);
    const v9 = root.reg.VReg.new(9, .int);
    const r8 = Reg.fromVReg(v8);
    const r9 = Reg.fromVReg(v9);

    // STLRB W8, [X9] - encoding: 0x089ffd28
    try emit(.{ .stlrb = .{
        .src = r8,
        .base = r9,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x089ffd28), insn);
}

test "emit stlrh - verify correct encoding" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);

    // STLRH W10, [X11] - encoding: 0x489ffd6a
    try emit(.{ .stlrh = .{
        .src = r10,
        .base = r11,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x489ffd6a), insn);
}

test "emit stlr_w - verify correct encoding" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v12 = root.reg.VReg.new(12, .int);
    const v13 = root.reg.VReg.new(13, .int);
    const r12 = Reg.fromVReg(v12);
    const r13 = Reg.fromVReg(v13);

    // STLR W12, [X13] - encoding: 0x889ffdac
    try emit(.{ .stlr_w = .{
        .src = r12,
        .base = r13,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x889ffdac), insn);
}

test "emit stlr_x - verify correct encoding" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v14 = root.reg.VReg.new(14, .int);
    const v15 = root.reg.VReg.new(15, .int);
    const r14 = Reg.fromVReg(v14);
    const r15 = Reg.fromVReg(v15);

    // STLR X14, [X15] - encoding: 0xc89ffdee
    try emit(.{ .stlr_x = .{
        .src = r14,
        .base = r15,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0xc89ffdee), insn);
}

test "emit ldr_shifted with no shift" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LDR X0, [X1, X2, LSL #0] - No shift, S bit should be 0
    try emit(.{ .ldr_shifted = .{
        .dst = wr0,
        .base = r1,
        .offset = r2,
        .shift_op = .lsl,
        .shift_amt = 0,
        .size = .size64,
    } }, &buffer);

    // Verify encoding: sf=1, Rm=2, option=011 (LSL), S=0 (no scale), Rn=1, Rt=0
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (1 << 31) | (0b11100001 << 21) | (2 << 16) | (0b011 << 13) | (0 << 12) | (0b10 << 10) | (1 << 5) | 0;
    try testing.expectEqual(expected, insn);
}

test "emit str_shifted with no shift" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = root.reg.VReg.new(5, .int);
    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const r5 = Reg.fromVReg(v5);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);

    // STR W5, [X6, X7, LSL #0] - No shift, S bit should be 0
    try emit(.{ .str_shifted = .{
        .src = r5,
        .base = r6,
        .offset = r7,
        .shift_op = .lsl,
        .shift_amt = 0,
        .size = .size32,
    } }, &buffer);

    // Verify encoding: sf=0, Rm=7, option=011 (LSL), S=0 (no scale), Rn=6, Rt=5
    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    const expected: u32 = (0 << 31) | (0b11100000 << 21) | (7 << 16) | (0b011 << 13) | (0 << 12) | (0b10 << 10) | (6 << 5) | 5;
    try testing.expectEqual(expected, insn);
}

test "emit ldr_shifted verifies encoding format" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const v12 = root.reg.VReg.new(12, .int);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const r12 = Reg.fromVReg(v12);
    const wr10 = root.reg.WritableReg.fromReg(r10);

    // LDR X10, [X11, X12, LSL #3]
    try emit(.{ .ldr_shifted = .{
        .dst = wr10,
        .base = r11,
        .offset = r12,
        .shift_op = .lsl,
        .shift_amt = 3,
        .size = .size64,
    } }, &buffer);

    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify individual bitfields per ARM Architecture Reference Manual
    // LDR (register) encoding: size|111|V|00|opc|1|Rm|option|S|10|Rn|Rt
    // For 64-bit GPR load: sf|111|0|00|01|1|Rm|011|S|10|Rn|Rt

    // sf (bit 31): 1 for 64-bit
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // bits 30-29: 11 (for load/store register offset)
    try testing.expectEqual(@as(u32, 0b11), (insn >> 29) & 0b11);

    // bits 28-27: 10 (V=0, fixed bits)
    try testing.expectEqual(@as(u32, 0b10), (insn >> 27) & 0b11);

    // bits 26-22: 00010 (opc=01 for LDR, fixed 1)
    try testing.expectEqual(@as(u32, 0b00010), (insn >> 22) & 0b11111);

    // bits 21: 1 (fixed)
    try testing.expectEqual(@as(u32, 1), (insn >> 21) & 1);

    // bits 20-16: Rm (12 in this case)
    try testing.expectEqual(@as(u32, 12), (insn >> 16) & 0x1F);

    // bits 15-13: option (011 for LSL)
    try testing.expectEqual(@as(u32, 0b011), (insn >> 13) & 0b111);

    // bit 12: S (1 for scaled)
    try testing.expectEqual(@as(u32, 1), (insn >> 12) & 1);

    // bits 11-10: 10 (fixed for register offset)
    try testing.expectEqual(@as(u32, 0b10), (insn >> 10) & 0b11);

    // bits 9-5: Rn (11 in this case)
    try testing.expectEqual(@as(u32, 11), (insn >> 5) & 0x1F);

    // bits 4-0: Rt (10 in this case)
    try testing.expectEqual(@as(u32, 10), insn & 0x1F);
}

test "emit str_shifted verifies encoding format" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = root.reg.VReg.new(20, .int);
    const v21 = root.reg.VReg.new(21, .int);
    const v22 = root.reg.VReg.new(22, .int);
    const r20 = Reg.fromVReg(v20);
    const r21 = Reg.fromVReg(v21);
    const r22 = Reg.fromVReg(v22);

    // STR W20, [X21, X22, LSL #2]
    try emit(.{ .str_shifted = .{
        .src = r20,
        .base = r21,
        .offset = r22,
        .shift_op = .lsl,
        .shift_amt = 2,
        .size = .size32,
    } }, &buffer);

    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify individual bitfields per ARM Architecture Reference Manual
    // STR (register) encoding: size|111|V|00|opc|1|Rm|option|S|10|Rn|Rt
    // For 32-bit GPR store: sf|111|0|00|00|1|Rm|011|S|10|Rn|Rt

    // sf (bit 31): 0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // bits 30-29: 11 (for load/store register offset)
    try testing.expectEqual(@as(u32, 0b11), (insn >> 29) & 0b11);

    // bits 28-27: 10 (V=0, fixed bits)
    try testing.expectEqual(@as(u32, 0b10), (insn >> 27) & 0b11);

    // bits 26-22: 00000 (opc=00 for STR, fixed 1)
    try testing.expectEqual(@as(u32, 0b00000), (insn >> 22) & 0b11111);

    // bits 21: 1 (fixed)
    try testing.expectEqual(@as(u32, 1), (insn >> 21) & 1);

    // bits 20-16: Rm (22 in this case)
    try testing.expectEqual(@as(u32, 22), (insn >> 16) & 0x1F);

    // bits 15-13: option (011 for LSL)
    try testing.expectEqual(@as(u32, 0b011), (insn >> 13) & 0b111);

    // bit 12: S (1 for scaled)
    try testing.expectEqual(@as(u32, 1), (insn >> 12) & 1);

    // bits 11-10: 10 (fixed for register offset)
    try testing.expectEqual(@as(u32, 0b10), (insn >> 10) & 0b11);

    // bits 9-5: Rn (21 in this case)
    try testing.expectEqual(@as(u32, 21), (insn >> 5) & 0x1F);

    // bits 4-0: Rt (20 in this case)
    try testing.expectEqual(@as(u32, 20), insn & 0x1F);
}

test "emit vec_add 4s" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const v2 = VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = WritableReg.fromReg(r0);

    // ADD V0.4S, V1.4S, V2.4S
    try emit(.{ .vec_add = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
        .size = .v4s,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Expected encoding: 0|Q|0|01110|size|1|Rm|100001|Rn|Rd
    // Q=1 (128-bit), size=10 (32-bit elements), opcode=100001
    // 0|1|001110|10|1|00010|100001|00001|00000
    // = 0x4E828420

    // bits 31: 0 (fixed)
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // bit 30: Q=1 (128-bit)
    try testing.expectEqual(@as(u32, 1), (insn >> 30) & 1);

    // bit 29: U=0 (unsigned/normal)
    try testing.expectEqual(@as(u32, 0), (insn >> 29) & 1);

    // bits 28-24: 01110 (SIMD three same)
    try testing.expectEqual(@as(u32, 0b01110), (insn >> 24) & 0b11111);

    // bits 23-22: size=10 (32-bit elements)
    try testing.expectEqual(@as(u32, 0b10), (insn >> 22) & 0b11);

    // bit 21: 1 (fixed)
    try testing.expectEqual(@as(u32, 1), (insn >> 21) & 1);

    // bits 20-16: Rm=2
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F);

    // bits 15-10: opcode=100001 (ADD)
    try testing.expectEqual(@as(u32, 0b100001), (insn >> 10) & 0b111111);

    // bits 9-5: Rn=1
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F);

    // bits 4-0: Rd=0
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);
}

test "emit vec_add 8b" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = VReg.new(10, .int);
    const v11 = VReg.new(11, .int);
    const v12 = VReg.new(12, .int);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const r12 = Reg.fromVReg(v12);
    const wr10 = WritableReg.fromReg(r10);

    // ADD V10.8B, V11.8B, V12.8B (64-bit vector)
    try emit(.{ .vec_add = .{
        .dst = wr10,
        .src1 = r11,
        .src2 = r12,
        .size = .v8b,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Q=0 (64-bit), size=00 (8-bit elements)
    try testing.expectEqual(@as(u32, 0), (insn >> 30) & 1); // Q=0
    try testing.expectEqual(@as(u32, 0b00), (insn >> 22) & 0b11); // size=00
    try testing.expectEqual(@as(u32, 12), (insn >> 16) & 0x1F); // Rm=12
    try testing.expectEqual(@as(u32, 0b100001), (insn >> 10) & 0b111111); // ADD opcode
    try testing.expectEqual(@as(u32, 11), (insn >> 5) & 0x1F); // Rn=11
    try testing.expectEqual(@as(u32, 10), insn & 0x1F); // Rd=10
}

test "emit vec_sub 8h" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = VReg.new(5, .int);
    const v6 = VReg.new(6, .int);
    const v7 = VReg.new(7, .int);
    const r5 = Reg.fromVReg(v5);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const wr5 = WritableReg.fromReg(r5);

    // SUB V5.8H, V6.8H, V7.8H
    try emit(.{ .vec_sub = .{
        .dst = wr5,
        .src1 = r6,
        .src2 = r7,
        .size = .v8h,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Expected encoding: 0|Q|1|01110|size|1|Rm|100001|Rn|Rd
    // Q=1 (128-bit), U=1 (for SUB), size=01 (16-bit elements)

    // bit 30: Q=1 (128-bit)
    try testing.expectEqual(@as(u32, 1), (insn >> 30) & 1);

    // bit 29: U=1 (for SUB)
    try testing.expectEqual(@as(u32, 1), (insn >> 29) & 1);

    // bits 23-22: size=01 (16-bit elements)
    try testing.expectEqual(@as(u32, 0b01), (insn >> 22) & 0b11);

    // bits 20-16: Rm=7
    try testing.expectEqual(@as(u32, 7), (insn >> 16) & 0x1F);

    // bits 15-10: opcode=100001 (SUB)
    try testing.expectEqual(@as(u32, 0b100001), (insn >> 10) & 0b111111);

    // bits 9-5: Rn=6
    try testing.expectEqual(@as(u32, 6), (insn >> 5) & 0x1F);

    // bits 4-0: Rd=5
    try testing.expectEqual(@as(u32, 5), insn & 0x1F);
}

test "emit vec_mul 2s" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = VReg.new(3, .int);
    const v4 = VReg.new(4, .int);
    const v5 = VReg.new(5, .int);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr3 = WritableReg.fromReg(r3);

    // MUL V3.2S, V4.2S, V5.2S (64-bit vector)
    try emit(.{ .vec_mul = .{
        .dst = wr3,
        .src1 = r4,
        .src2 = r5,
        .size = .v2s,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Expected encoding: 0|Q|0|01110|size|1|Rm|100111|Rn|Rd
    // Q=0 (64-bit), size=10 (32-bit elements), opcode=100111

    // bit 30: Q=0 (64-bit)
    try testing.expectEqual(@as(u32, 0), (insn >> 30) & 1);

    // bits 23-22: size=10 (32-bit elements)
    try testing.expectEqual(@as(u32, 0b10), (insn >> 22) & 0b11);

    // bits 20-16: Rm=5
    try testing.expectEqual(@as(u32, 5), (insn >> 16) & 0x1F);

    // bits 15-10: opcode=100111 (MUL)
    try testing.expectEqual(@as(u32, 0b100111), (insn >> 10) & 0b111111);

    // bits 9-5: Rn=4
    try testing.expectEqual(@as(u32, 4), (insn >> 5) & 0x1F);

    // bits 4-0: Rd=3
    try testing.expectEqual(@as(u32, 3), insn & 0x1F);
}

test "emit vec_mul 16b" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v15 = VReg.new(15, .int);
    const v16 = VReg.new(16, .int);
    const v17 = VReg.new(17, .int);
    const r15 = Reg.fromVReg(v15);
    const r16 = Reg.fromVReg(v16);
    const r17 = Reg.fromVReg(v17);
    const wr15 = WritableReg.fromReg(r15);

    // MUL V15.16B, V16.16B, V17.16B (128-bit vector)
    try emit(.{ .vec_mul = .{
        .dst = wr15,
        .src1 = r16,
        .src2 = r17,
        .size = .v16b,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Q=1 (128-bit), size=00 (8-bit elements)
    try testing.expectEqual(@as(u32, 1), (insn >> 30) & 1); // Q=1
    try testing.expectEqual(@as(u32, 0b00), (insn >> 22) & 0b11); // size=00
    try testing.expectEqual(@as(u32, 17), (insn >> 16) & 0x1F); // Rm=17
    try testing.expectEqual(@as(u32, 0b100111), (insn >> 10) & 0b111111); // MUL opcode
    try testing.expectEqual(@as(u32, 16), (insn >> 5) & 0x1F); // Rn=16
    try testing.expectEqual(@as(u32, 15), insn & 0x1F); // Rd=15
}

test "emit vec_add 2d" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v20 = VReg.new(20, .int);
    const v21 = VReg.new(21, .int);
    const v22 = VReg.new(22, .int);
    const r20 = Reg.fromVReg(v20);
    const r21 = Reg.fromVReg(v21);
    const r22 = Reg.fromVReg(v22);
    const wr20 = WritableReg.fromReg(r20);

    // ADD V20.2D, V21.2D, V22.2D (128-bit vector with 64-bit elements)
    try emit(.{ .vec_add = .{
        .dst = wr20,
        .src1 = r21,
        .src2 = r22,
        .size = .v2d,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Q=1 (128-bit), size=11 (64-bit elements)
    try testing.expectEqual(@as(u32, 1), (insn >> 30) & 1); // Q=1
    try testing.expectEqual(@as(u32, 0b11), (insn >> 22) & 0b11); // size=11
    try testing.expectEqual(@as(u32, 22), (insn >> 16) & 0x1F); // Rm=22
    try testing.expectEqual(@as(u32, 0b100001), (insn >> 10) & 0b111111); // ADD opcode
    try testing.expectEqual(@as(u32, 21), (insn >> 5) & 0x1F); // Rn=21
    try testing.expectEqual(@as(u32, 20), insn & 0x1F); // Rd=20
}

test "emit sxtb 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // SXTB W0, W1 (sign extend byte to 32-bit)
    try emit(.{ .sxtb = .{
        .dst = wr0,
        .src = r1,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // SBFM W0, W1, #0, #7
    // sf=0, opc=00, N=0, immr=0, imms=7, Rn=1, Rd=0
    const expected: u32 = (0 << 31) | (0b00100110 << 23) | (0 << 22) | (0 << 16) | (7 << 10) | (1 << 5) | 0;
    try testing.expectEqual(expected, insn);
}

test "emit sxtb 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v2 = root.reg.VReg.new(2, .int);
    const v3 = root.reg.VReg.new(3, .int);
    const r2 = Reg.fromVReg(v2);
    const r3 = Reg.fromVReg(v3);
    const wr2 = root.reg.WritableReg.fromReg(r2);

    // SXTB X2, W3 (sign extend byte to 64-bit)
    try emit(.{ .sxtb = .{
        .dst = wr2,
        .src = r3,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // SBFM X2, X3, #0, #7
    // sf=1, opc=00, N=1, immr=0, imms=7, Rn=3, Rd=2
    const expected: u32 = (1 << 31) | (0b00100110 << 23) | (1 << 22) | (0 << 16) | (7 << 10) | (3 << 5) | 2;
    try testing.expectEqual(expected, insn);
}

test "emit sxth 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v4 = root.reg.VReg.new(4, .int);
    const v5 = root.reg.VReg.new(5, .int);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr4 = root.reg.WritableReg.fromReg(r4);

    // SXTH W4, W5 (sign extend halfword to 32-bit)
    try emit(.{ .sxth = .{
        .dst = wr4,
        .src = r5,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // SBFM W4, W5, #0, #15
    // sf=0, opc=00, N=0, immr=0, imms=15, Rn=5, Rd=4
    const expected: u32 = (0 << 31) | (0b00100110 << 23) | (0 << 22) | (0 << 16) | (15 << 10) | (5 << 5) | 4;
    try testing.expectEqual(expected, insn);
}

test "emit sxth 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v6 = root.reg.VReg.new(6, .int);
    const v7 = root.reg.VReg.new(7, .int);
    const r6 = Reg.fromVReg(v6);
    const r7 = Reg.fromVReg(v7);
    const wr6 = root.reg.WritableReg.fromReg(r6);

    // SXTH X6, W7 (sign extend halfword to 64-bit)
    try emit(.{ .sxth = .{
        .dst = wr6,
        .src = r7,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // SBFM X6, X7, #0, #15
    // sf=1, opc=00, N=1, immr=0, imms=15, Rn=7, Rd=6
    const expected: u32 = (1 << 31) | (0b00100110 << 23) | (1 << 22) | (0 << 16) | (15 << 10) | (7 << 5) | 6;
    try testing.expectEqual(expected, insn);
}

test "emit sxtw" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v8 = root.reg.VReg.new(8, .int);
    const v9 = root.reg.VReg.new(9, .int);
    const r8 = Reg.fromVReg(v8);
    const r9 = Reg.fromVReg(v9);
    const wr8 = root.reg.WritableReg.fromReg(r8);

    // SXTW X8, W9 (sign extend word to 64-bit)
    try emit(.{ .sxtw = .{
        .dst = wr8,
        .src = r9,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // SBFM X8, X9, #0, #31
    // sf=1, opc=00, N=1, immr=0, imms=31, Rn=9, Rd=8
    const expected: u32 = (1 << 31) | (0b00100110 << 23) | (1 << 22) | (0 << 16) | (31 << 10) | (9 << 5) | 8;
    try testing.expectEqual(expected, insn);
}

test "emit uxtb 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = root.reg.VReg.new(10, .int);
    const v11 = root.reg.VReg.new(11, .int);
    const r10 = Reg.fromVReg(v10);
    const r11 = Reg.fromVReg(v11);
    const wr10 = root.reg.WritableReg.fromReg(r10);

    // UXTB W10, W11 (zero extend byte to 32-bit)
    try emit(.{ .uxtb = .{
        .dst = wr10,
        .src = r11,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // UBFM W10, W11, #0, #7
    // sf=0, opc=10, N=0, immr=0, imms=7, Rn=11, Rd=10
    const expected: u32 = (0 << 31) | (0b10100110 << 23) | (0 << 22) | (0 << 16) | (7 << 10) | (11 << 5) | 10;
    try testing.expectEqual(expected, insn);
}

test "emit uxtb 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v12 = root.reg.VReg.new(12, .int);
    const v13 = root.reg.VReg.new(13, .int);
    const r12 = Reg.fromVReg(v12);
    const r13 = Reg.fromVReg(v13);
    const wr12 = root.reg.WritableReg.fromReg(r12);

    // UXTB X12, W13 (zero extend byte to 64-bit)
    try emit(.{ .uxtb = .{
        .dst = wr12,
        .src = r13,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // UBFM X12, X13, #0, #7
    // sf=1, opc=10, N=1, immr=0, imms=7, Rn=13, Rd=12
    const expected: u32 = (1 << 31) | (0b10100110 << 23) | (1 << 22) | (0 << 16) | (7 << 10) | (13 << 5) | 12;
    try testing.expectEqual(expected, insn);
}

test "emit uxth 32-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v14 = root.reg.VReg.new(14, .int);
    const v15 = root.reg.VReg.new(15, .int);
    const r14 = Reg.fromVReg(v14);
    const r15 = Reg.fromVReg(v15);
    const wr14 = root.reg.WritableReg.fromReg(r14);

    // UXTH W14, W15 (zero extend halfword to 32-bit)
    try emit(.{ .uxth = .{
        .dst = wr14,
        .src = r15,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // UBFM W14, W15, #0, #15
    // sf=0, opc=10, N=0, immr=0, imms=15, Rn=15, Rd=14
    const expected: u32 = (0 << 31) | (0b10100110 << 23) | (0 << 22) | (0 << 16) | (15 << 10) | (15 << 5) | 14;
    try testing.expectEqual(expected, insn);
}

test "emit uxth 64-bit" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v16 = root.reg.VReg.new(16, .int);
    const v17 = root.reg.VReg.new(17, .int);
    const r16 = Reg.fromVReg(v16);
    const r17 = Reg.fromVReg(v17);
    const wr16 = root.reg.WritableReg.fromReg(r16);

    // UXTH X16, W17 (zero extend halfword to 64-bit)
    try emit(.{ .uxth = .{
        .dst = wr16,
        .src = r17,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // UBFM X16, X17, #0, #15
    // sf=1, opc=10, N=1, immr=0, imms=15, Rn=17, Rd=16
    const expected: u32 = (1 << 31) | (0b10100110 << 23) | (1 << 22) | (0 << 16) | (15 << 10) | (17 << 5) | 16;
    try testing.expectEqual(expected, insn);
}

test "emit extend instructions - verify against ARM manual examples" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // Test SXTB W0, W1 encoding: should be 0x13001C20
    buffer.reset();
    try emit(.{ .sxtb = .{
        .dst = wr0,
        .src = r1,
        .size = .size32,
    } }, &buffer);
    var insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x13001C20), insn);

    // Test SXTB X0, W1 encoding: should be 0x93401C20
    buffer.reset();
    try emit(.{ .sxtb = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x93401C20), insn);

    // Test SXTH W0, W1 encoding: should be 0x13003C20
    buffer.reset();
    try emit(.{ .sxth = .{
        .dst = wr0,
        .src = r1,
        .size = .size32,
    } }, &buffer);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x13003C20), insn);

    // Test SXTH X0, W1 encoding: should be 0x93403C20
    buffer.reset();
    try emit(.{ .sxth = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x93403C20), insn);

    // Test SXTW X0, W1 encoding: should be 0x93407C20
    buffer.reset();
    try emit(.{ .sxtw = .{
        .dst = wr0,
        .src = r1,
    } }, &buffer);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x93407C20), insn);

    // Test UXTB W0, W1 encoding: should be 0x53001C20
    buffer.reset();
    try emit(.{ .uxtb = .{
        .dst = wr0,
        .src = r1,
        .size = .size32,
    } }, &buffer);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x53001C20), insn);

    // Test UXTB X0, W1 encoding (actually implemented as UBFM with sf=1): should be 0xD3401C20
    buffer.reset();
    try emit(.{ .uxtb = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0xD3401C20), insn);

    // Test UXTH W0, W1 encoding: should be 0x53003C20
    buffer.reset();
    try emit(.{ .uxth = .{
        .dst = wr0,
        .src = r1,
        .size = .size32,
    } }, &buffer);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x53003C20), insn);

    // Test UXTH X0, W1 encoding (actually implemented as UBFM with sf=1): should be 0xD3403C20
    buffer.reset();
    try emit(.{ .uxth = .{
        .dst = wr0,
        .src = r1,
        .size = .size64,
    } }, &buffer);
    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0xD3403C20), insn);
}

test "emit adr positive offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = VReg.new(0, .int);
    const r0 = Reg.fromVReg(v0);
    const wr0 = WritableReg.fromReg(r0);

    // ADR X0, #0x1234 (positive offset)
    try emit(.{ .adr = .{
        .dst = wr0,
        .offset = 0x1234,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check op bit (bit 31) = 0 for ADR
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check opcode (bits 28-24) = 10000
    try testing.expectEqual(@as(u32, 0b10000), (insn >> 24) & 0b11111);

    // Check Rd (bits 4-0) = 0
    try testing.expectEqual(@as(u32, 0), insn & 0x1F);

    // Check encoding of immediate (offset 0x1234 = 0b0001001000110100)
    // immlo = bits [1:0] = 00
    // immhi = bits [20:2] = 0b0000100100011010
    const immlo = (insn >> 29) & 0b11;
    const immhi = (insn >> 5) & 0x7FFFF;
    const decoded_offset = (immhi << 2) | immlo;
    try testing.expectEqual(@as(u32, 0x1234), decoded_offset);
}

test "emit adr negative offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = VReg.new(5, .int);
    const r5 = Reg.fromVReg(v5);
    const wr5 = WritableReg.fromReg(r5);

    // ADR X5, #-0x100 (negative offset)
    try emit(.{ .adr = .{
        .dst = wr5,
        .offset = -0x100,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check op bit = 0 for ADR
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Check Rd = 5
    try testing.expectEqual(@as(u32, 5), insn & 0x1F);

    // Check encoding preserves negative offset
    const immlo = (insn >> 29) & 0b11;
    const immhi = (insn >> 5) & 0x7FFFF;
    const decoded_offset_u = (immhi << 2) | immlo;
    const decoded_offset: i32 = @bitCast(decoded_offset_u);
    try testing.expectEqual(@as(i32, -0x100), decoded_offset);
}

test "emit adr zero offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v10 = VReg.new(10, .int);
    const r10 = Reg.fromVReg(v10);
    const wr10 = WritableReg.fromReg(r10);

    // ADR X10, #0
    try emit(.{ .adr = .{
        .dst = wr10,
        .offset = 0,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check Rd = 10
    try testing.expectEqual(@as(u32, 10), insn & 0x1F);

    // Check offset is zero
    const immlo = (insn >> 29) & 0b11;
    const immhi = (insn >> 5) & 0x7FFFF;
    try testing.expectEqual(@as(u32, 0), immlo);
    try testing.expectEqual(@as(u32, 0), immhi);
}

test "emit adrp positive offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v2 = VReg.new(2, .int);
    const r2 = Reg.fromVReg(v2);
    const wr2 = WritableReg.fromReg(r2);

    // ADRP X2, #0x5000 (page offset)
    try emit(.{ .adrp = .{
        .dst = wr2,
        .offset = 0x5000,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check op bit (bit 31) = 1 for ADRP
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check opcode (bits 28-24) = 10000
    try testing.expectEqual(@as(u32, 0b10000), (insn >> 24) & 0b11111);

    // Check Rd = 2
    try testing.expectEqual(@as(u32, 2), insn & 0x1F);

    // Check encoding of immediate
    const immlo = (insn >> 29) & 0b11;
    const immhi = (insn >> 5) & 0x7FFFF;
    const decoded_offset = (immhi << 2) | immlo;
    try testing.expectEqual(@as(u32, 0x5000), decoded_offset);
}

test "emit adrp negative offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v7 = VReg.new(7, .int);
    const r7 = Reg.fromVReg(v7);
    const wr7 = WritableReg.fromReg(r7);

    // ADRP X7, #-0x2000
    try emit(.{ .adrp = .{
        .dst = wr7,
        .offset = -0x2000,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check op bit = 1 for ADRP
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1);

    // Check Rd = 7
    try testing.expectEqual(@as(u32, 7), insn & 0x1F);

    // Check encoding preserves negative offset
    const immlo = (insn >> 29) & 0b11;
    const immhi = (insn >> 5) & 0x7FFFF;
    const decoded_offset_u = (immhi << 2) | immlo;
    const decoded_offset: i32 = @bitCast(decoded_offset_u);
    try testing.expectEqual(@as(i32, -0x2000), decoded_offset);
}

test "emit adr max positive offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v1 = VReg.new(1, .int);
    const r1 = Reg.fromVReg(v1);
    const wr1 = WritableReg.fromReg(r1);

    // ADR X1, #0xFFFFF (max positive 21-bit signed value = 1048575)
    try emit(.{ .adr = .{
        .dst = wr1,
        .offset = (1 << 20) - 1,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Decode and verify
    const immlo = (insn >> 29) & 0b11;
    const immhi = (insn >> 5) & 0x7FFFF;
    const decoded_offset = (immhi << 2) | immlo;
    try testing.expectEqual(@as(u32, (1 << 20) - 1), decoded_offset);
}

test "emit adr max negative offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = VReg.new(3, .int);
    const r3 = Reg.fromVReg(v3);
    const wr3 = WritableReg.fromReg(r3);

    // ADR X3, #-0x100000 (min 21-bit signed value = -1048576)
    try emit(.{ .adr = .{
        .dst = wr3,
        .offset = -(1 << 20),
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Decode and verify
    const immlo = (insn >> 29) & 0b11;
    const immhi = (insn >> 5) & 0x7FFFF;
    const decoded_offset_u = (immhi << 2) | immlo;
    const decoded_offset: i32 = @bitCast(decoded_offset_u);
    try testing.expectEqual(@as(i32, -(1 << 20)), decoded_offset);
}

test "emit adr/adrp different registers" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // Test multiple registers to ensure encoding is correct
    const registers = [_]u5{ 0, 5, 10, 15, 20, 25, 30 };
    for (registers) |reg_num| {
        buffer.data.clearRetainingCapacity();

        const v = VReg.new(reg_num, .int);
        const r = Reg.fromVReg(v);
        const wr = WritableReg.fromReg(r);

        try emit(.{ .adr = .{
            .dst = wr,
            .offset = 0x100,
        } }, &buffer);

        const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
        try testing.expectEqual(@as(u32, reg_num), insn & 0x1F);
    }
}

test "emit ldr_pre 64-bit positive offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);
    const wr1 = WritableReg.fromReg(r1);

    // LDR X0, [X1, #16]!
    try emit(.{ .ldr_pre = .{
        .dst = wr0,
        .base = wr1,
        .offset = 16,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify encoding: sf=1, opc=01, imm9=16, index=11, Rn=1, Rt=0
    // sf|111|0|00|01|imm9|11|Rn|Rt
    const expected: u32 = (1 << 31) | // sf=1 (64-bit)
        (0b11100001 << 21) | // 111|0|00|01
        (16 << 12) | // imm9=16
        (0b11 << 10) | // pre-index
        (1 << 5) | // Rn=1
        0; // Rt=0
    try testing.expectEqual(expected, insn);

    // Verify individual fields
    try testing.expectEqual(@as(u32, 1), (insn >> 31) & 1); // sf bit
    try testing.expectEqual(@as(u32, 0b11), (insn >> 10) & 0b11); // pre-index mode
    try testing.expectEqual(@as(u32, 16), (insn >> 12) & 0x1FF); // imm9
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F); // base reg
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // dest reg
}

test "emit ldr_pre 64-bit negative offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v5 = VReg.new(5, .int);
    const v10 = VReg.new(10, .int);
    const r5 = Reg.fromVReg(v5);
    const r10 = Reg.fromVReg(v10);
    const wr5 = WritableReg.fromReg(r5);
    const wr10 = WritableReg.fromReg(r10);

    // LDR X5, [X10, #-32]!
    try emit(.{ .ldr_pre = .{
        .dst = wr5,
        .base = wr10,
        .offset = -32,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify pre-index mode bits
    try testing.expectEqual(@as(u32, 0b11), (insn >> 10) & 0b11);

    // Verify negative offset encoding
    const imm9 = (insn >> 12) & 0x1FF;
    const signed_offset: i16 = @bitCast(@as(u16, @truncate(imm9)));
    try testing.expectEqual(@as(i16, -32), signed_offset);

    // Verify registers
    try testing.expectEqual(@as(u32, 10), (insn >> 5) & 0x1F); // base reg
    try testing.expectEqual(@as(u32, 5), insn & 0x1F); // dest reg
}

test "emit ldr_pre 32-bit" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v2 = VReg.new(2, .int);
    const v3 = VReg.new(3, .int);
    const r2 = Reg.fromVReg(v2);
    const r3 = Reg.fromVReg(v3);
    const wr2 = WritableReg.fromReg(r2);
    const wr3 = WritableReg.fromReg(r3);

    // LDR W2, [X3, #8]!
    try emit(.{ .ldr_pre = .{
        .dst = wr2,
        .base = wr3,
        .offset = 8,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify sf=0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify pre-index mode
    try testing.expectEqual(@as(u32, 0b11), (insn >> 10) & 0b11);

    // Verify offset
    try testing.expectEqual(@as(u32, 8), (insn >> 12) & 0x1FF);
}

test "emit ldr_post 64-bit positive offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v7 = VReg.new(7, .int);
    const v8 = VReg.new(8, .int);
    const r7 = Reg.fromVReg(v7);
    const r8 = Reg.fromVReg(v8);
    const wr7 = WritableReg.fromReg(r7);
    const wr8 = WritableReg.fromReg(r8);

    // LDR X7, [X8], #24
    try emit(.{ .ldr_post = .{
        .dst = wr7,
        .base = wr8,
        .offset = 24,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify encoding: sf=1, opc=01, imm9=24, index=01, Rn=8, Rt=7
    const expected: u32 = (1 << 31) | // sf=1 (64-bit)
        (0b11100001 << 21) | // 111|0|00|01
        (24 << 12) | // imm9=24
        (0b01 << 10) | // post-index
        (8 << 5) | // Rn=8
        7; // Rt=7
    try testing.expectEqual(expected, insn);

    // Verify post-index mode bits
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0b11);
}

test "emit ldr_post 64-bit negative offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v15 = VReg.new(15, .int);
    const v20 = VReg.new(20, .int);
    const r15 = Reg.fromVReg(v15);
    const r20 = Reg.fromVReg(v20);
    const wr15 = WritableReg.fromReg(r15);
    const wr20 = WritableReg.fromReg(r20);

    // LDR X15, [X20], #-48
    try emit(.{ .ldr_post = .{
        .dst = wr15,
        .base = wr20,
        .offset = -48,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify post-index mode
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0b11);

    // Verify negative offset encoding
    const imm9 = (insn >> 12) & 0x1FF;
    const signed_offset: i16 = @bitCast(@as(u16, @truncate(imm9)));
    try testing.expectEqual(@as(i16, -48), signed_offset);

    // Verify registers
    try testing.expectEqual(@as(u32, 20), (insn >> 5) & 0x1F); // base reg
    try testing.expectEqual(@as(u32, 15), insn & 0x1F); // dest reg
}

test "emit ldr_post 32-bit" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v11 = VReg.new(11, .int);
    const v12 = VReg.new(12, .int);
    const r11 = Reg.fromVReg(v11);
    const r12 = Reg.fromVReg(v12);
    const wr11 = WritableReg.fromReg(r11);
    const wr12 = WritableReg.fromReg(r12);

    // LDR W11, [X12], #4
    try emit(.{ .ldr_post = .{
        .dst = wr11,
        .base = wr12,
        .offset = 4,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify sf=0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify post-index mode
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0b11);

    // Verify offset
    try testing.expectEqual(@as(u32, 4), (insn >> 12) & 0x1FF);
}

test "emit str_pre 64-bit positive offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v9 = VReg.new(9, .int);
    const v13 = VReg.new(13, .int);
    const r9 = Reg.fromVReg(v9);
    const r13 = Reg.fromVReg(v13);
    const wr13 = WritableReg.fromReg(r13);

    // STR X9, [X13, #64]!
    try emit(.{ .str_pre = .{
        .src = r9,
        .base = wr13,
        .offset = 64,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify encoding: sf=1, opc=00, imm9=64, index=11, Rn=13, Rt=9
    // sf|111|0|00|00|imm9|11|Rn|Rt
    const expected: u32 = (1 << 31) | // sf=1 (64-bit)
        (0b11100000 << 21) | // 111|0|00|00
        (64 << 12) | // imm9=64
        (0b11 << 10) | // pre-index
        (13 << 5) | // Rn=13
        9; // Rt=9
    try testing.expectEqual(expected, insn);

    // Verify pre-index mode
    try testing.expectEqual(@as(u32, 0b11), (insn >> 10) & 0b11);

    // Verify it's a store (opc bits different from load)
    try testing.expectEqual(@as(u32, 0b11100000), (insn >> 21) & 0xFF);
}

test "emit str_pre 64-bit negative offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v4 = VReg.new(4, .int);
    const v6 = VReg.new(6, .int);
    const r4 = Reg.fromVReg(v4);
    const r6 = Reg.fromVReg(v6);
    const wr6 = WritableReg.fromReg(r6);

    // STR X4, [X6, #-16]!
    try emit(.{ .str_pre = .{
        .src = r4,
        .base = wr6,
        .offset = -16,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify pre-index mode
    try testing.expectEqual(@as(u32, 0b11), (insn >> 10) & 0b11);

    // Verify negative offset
    const imm9 = (insn >> 12) & 0x1FF;
    const signed_offset: i16 = @bitCast(@as(u16, @truncate(imm9)));
    try testing.expectEqual(@as(i16, -16), signed_offset);

    // Verify registers
    try testing.expectEqual(@as(u32, 6), (insn >> 5) & 0x1F); // base reg
    try testing.expectEqual(@as(u32, 4), insn & 0x1F); // src reg
}

test "emit str_pre 32-bit" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v14 = VReg.new(14, .int);
    const v16 = VReg.new(16, .int);
    const r14 = Reg.fromVReg(v14);
    const r16 = Reg.fromVReg(v16);
    const wr16 = WritableReg.fromReg(r16);

    // STR W14, [X16, #12]!
    try emit(.{ .str_pre = .{
        .src = r14,
        .base = wr16,
        .offset = 12,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify sf=0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify pre-index mode
    try testing.expectEqual(@as(u32, 0b11), (insn >> 10) & 0b11);

    // Verify offset
    try testing.expectEqual(@as(u32, 12), (insn >> 12) & 0x1FF);
}

test "emit str_post 64-bit positive offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v17 = VReg.new(17, .int);
    const v18 = VReg.new(18, .int);
    const r17 = Reg.fromVReg(v17);
    const r18 = Reg.fromVReg(v18);
    const wr18 = WritableReg.fromReg(r18);

    // STR X17, [X18], #80
    try emit(.{ .str_post = .{
        .src = r17,
        .base = wr18,
        .offset = 80,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify encoding: sf=1, opc=00, imm9=80, index=01, Rn=18, Rt=17
    const expected: u32 = (1 << 31) | // sf=1 (64-bit)
        (0b11100000 << 21) | // 111|0|00|00
        (80 << 12) | // imm9=80
        (0b01 << 10) | // post-index
        (18 << 5) | // Rn=18
        17; // Rt=17
    try testing.expectEqual(expected, insn);

    // Verify post-index mode
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0b11);
}

test "emit str_post 64-bit negative offset" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v21 = VReg.new(21, .int);
    const v22 = VReg.new(22, .int);
    const r21 = Reg.fromVReg(v21);
    const r22 = Reg.fromVReg(v22);
    const wr22 = WritableReg.fromReg(r22);

    // STR X21, [X22], #-128
    try emit(.{ .str_post = .{
        .src = r21,
        .base = wr22,
        .offset = -128,
        .size = .size64,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify post-index mode
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0b11);

    // Verify negative offset
    const imm9 = (insn >> 12) & 0x1FF;
    const signed_offset: i16 = @bitCast(@as(u16, @truncate(imm9)));
    try testing.expectEqual(@as(i16, -128), signed_offset);

    // Verify registers
    try testing.expectEqual(@as(u32, 22), (insn >> 5) & 0x1F); // base reg
    try testing.expectEqual(@as(u32, 21), insn & 0x1F); // src reg
}

test "emit str_post 32-bit" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v25 = VReg.new(25, .int);
    const v26 = VReg.new(26, .int);
    const r25 = Reg.fromVReg(v25);
    const r26 = Reg.fromVReg(v26);
    const wr26 = WritableReg.fromReg(r26);

    // STR W25, [X26], #20
    try emit(.{ .str_post = .{
        .src = r25,
        .base = wr26,
        .offset = 20,
        .size = .size32,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify sf=0 for 32-bit
    try testing.expectEqual(@as(u32, 0), (insn >> 31) & 1);

    // Verify post-index mode
    try testing.expectEqual(@as(u32, 0b01), (insn >> 10) & 0b11);

    // Verify offset
    try testing.expectEqual(@as(u32, 20), (insn >> 12) & 0x1FF);
}

test "emit ldr/str pre/post index boundary values" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);
    const wr1 = WritableReg.fromReg(r1);

    // Test max positive offset (255)
    buffer.data.clearRetainingCapacity();
    try emit(.{ .ldr_pre = .{
        .dst = wr0,
        .base = wr1,
        .offset = 255,
        .size = .size64,
    } }, &buffer);

    var insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    var imm9 = (insn >> 12) & 0x1FF;
    try testing.expectEqual(@as(u32, 255), imm9);

    // Test max negative offset (-256)
    buffer.data.clearRetainingCapacity();
    try emit(.{ .ldr_post = .{
        .dst = wr0,
        .base = wr1,
        .offset = -256,
        .size = .size64,
    } }, &buffer);

    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    imm9 = (insn >> 12) & 0x1FF;
    const signed_offset: i16 = @bitCast(@as(u16, @truncate(imm9)));
    try testing.expectEqual(@as(i16, -256), signed_offset);

    // Test zero offset
    buffer.data.clearRetainingCapacity();
    try emit(.{ .str_pre = .{
        .src = r0,
        .base = wr1,
        .offset = 0,
        .size = .size64,
    } }, &buffer);

    insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    imm9 = (insn >> 12) & 0x1FF;
    try testing.expectEqual(@as(u32, 0), imm9);
}

test "emit ldr/str pre/post verify opcode differences" {
    const VReg = root.reg.VReg;
    const WritableReg = root.reg.WritableReg;

    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = VReg.new(0, .int);
    const v1 = VReg.new(1, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = WritableReg.fromReg(r0);
    const wr1 = WritableReg.fromReg(r1);

    // LDR pre-index
    try emit(.{ .ldr_pre = .{
        .dst = wr0,
        .base = wr1,
        .offset = 8,
        .size = .size64,
    } }, &buffer);
    const ldr_pre_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // LDR post-index
    buffer.data.clearRetainingCapacity();
    try emit(.{ .ldr_post = .{
        .dst = wr0,
        .base = wr1,
        .offset = 8,
        .size = .size64,
    } }, &buffer);
    const ldr_post_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // STR pre-index
    buffer.data.clearRetainingCapacity();
    try emit(.{ .str_pre = .{
        .src = r0,
        .base = wr1,
        .offset = 8,
        .size = .size64,
    } }, &buffer);
    const str_pre_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // STR post-index
    buffer.data.clearRetainingCapacity();
    try emit(.{ .str_post = .{
        .src = r0,
        .base = wr1,
        .offset = 8,
        .size = .size64,
    } }, &buffer);
    const str_post_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Verify LDR vs STR have different opc bits (bit 22 differs)
    // LDR has opc=01 (bit 22 = 1), STR has opc=00 (bit 22 = 0)
    try testing.expectEqual(@as(u32, 1), (ldr_pre_insn >> 22) & 1);
    try testing.expectEqual(@as(u32, 1), (ldr_post_insn >> 22) & 1);
    try testing.expectEqual(@as(u32, 0), (str_pre_insn >> 22) & 1);
    try testing.expectEqual(@as(u32, 0), (str_post_insn >> 22) & 1);

    // Verify pre vs post have different index bits (bits 11:10)
    // Pre-index = 11, post-index = 01
    try testing.expectEqual(@as(u32, 0b11), (ldr_pre_insn >> 10) & 0b11);
    try testing.expectEqual(@as(u32, 0b01), (ldr_post_insn >> 10) & 0b11);
    try testing.expectEqual(@as(u32, 0b11), (str_pre_insn >> 10) & 0b11);
    try testing.expectEqual(@as(u32, 0b01), (str_post_insn >> 10) & 0b11);
}

// === Floating-Point Instruction Tests ===

test "emit fadd single-precision" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .float);
    const v1 = root.reg.VReg.new(1, .float);
    const v2 = root.reg.VReg.new(2, .float);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // FADD S0, S1, S2
    try emit(.{ .fadd_s = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check ftype bits (22-23) = 00 for single-precision
    try testing.expectEqual(@as(u32, 0b00), (insn >> 22) & 0b11);

    // Check opcode (10-15) = 001010 for FADD
    try testing.expectEqual(@as(u32, 0b001010), (insn >> 10) & 0b111111);

    // Check registers
    try testing.expectEqual(@as(u32, 0), insn & 0x1F); // Rd = S0
    try testing.expectEqual(@as(u32, 1), (insn >> 5) & 0x1F); // Rn = S1
    try testing.expectEqual(@as(u32, 2), (insn >> 16) & 0x1F); // Rm = S2

    // Verify full encoding: 0x1E221820 (FADD S0, S1, S2)
    try testing.expectEqual(@as(u32, 0x1E221820), insn);
}

test "emit fadd double-precision" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v3 = root.reg.VReg.new(3, .float);
    const v4 = root.reg.VReg.new(4, .float);
    const v5 = root.reg.VReg.new(5, .float);
    const r3 = Reg.fromVReg(v3);
    const r4 = Reg.fromVReg(v4);
    const r5 = Reg.fromVReg(v5);
    const wr3 = root.reg.WritableReg.fromReg(r3);

    // FADD D3, D4, D5
    try emit(.{ .fadd_d = .{
        .dst = wr3,
        .src1 = r4,
        .src2 = r5,
    } }, &buffer);

    try testing.expectEqual(@as(usize, 4), buffer.data.items.len);
    const insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);

    // Check ftype bits (22-23) = 01 for double-precision
    try testing.expectEqual(@as(u32, 0b01), (insn >> 22) & 0b11);

    // Verify full encoding: 0x1E652883 (FADD D3, D4, D5)
    try testing.expectEqual(@as(u32, 0x1E652883), insn);
}

test "emit fsub and fmul" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .float);
    const v1 = root.reg.VReg.new(1, .float);
    const v2 = root.reg.VReg.new(2, .float);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // FSUB S0, S1, S2
    try emit(.{ .fsub_s = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } }, &buffer);
    const fsub_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0b001110), (fsub_insn >> 10) & 0b111111);

    // FMUL S0, S1, S2
    buffer.data.clearRetainingCapacity();
    try emit(.{ .fmul_s = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } }, &buffer);
    const fmul_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0b000010), (fmul_insn >> 10) & 0b111111);

    // FDIV D0, D1, D2
    buffer.data.clearRetainingCapacity();
    try emit(.{ .fdiv_d = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } }, &buffer);
    const fdiv_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0b000110), (fdiv_insn >> 10) & 0b111111);
    try testing.expectEqual(@as(u32, 0b01), (fdiv_insn >> 22) & 0b11);
}

test "emit fmov register and immediate" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .float);
    const v1 = root.reg.VReg.new(1, .float);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // FMOV S0, S1
    try emit(.{ .fmov_rr_s = .{
        .dst = wr0,
        .src = r1,
    } }, &buffer);
    const fmov_rr_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x1E204020), fmov_rr_insn);

    // FMOV S0, #0.0
    buffer.data.clearRetainingCapacity();
    try emit(.{ .fmov_imm_s = .{
        .dst = wr0,
        .imm = 0.0,
    } }, &buffer);
    const fmov_imm_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x1E201000), fmov_imm_insn);
}

test "emit fcmp and fcvt" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .float);
    const v1 = root.reg.VReg.new(1, .float);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // FCMP S0, S1
    try emit(.{ .fcmp_s = .{
        .src1 = r0,
        .src2 = r1,
    } }, &buffer);
    const fcmp_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x1E212000), fcmp_insn);

    // FCVT D0, S1
    buffer.data.clearRetainingCapacity();
    try emit(.{ .fcvt_s_to_d = .{
        .dst = wr0,
        .src = r1,
    } }, &buffer);
    const fcvt_s_to_d_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x1E22C020), fcvt_s_to_d_insn);
}

test "emit scvtf and fcvtzs conversions" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0_int = root.reg.VReg.new(0, .int);
    const v1_float = root.reg.VReg.new(1, .float);
    const r0 = Reg.fromVReg(v0_int);
    const r1 = Reg.fromVReg(v1_float);
    const wr1 = root.reg.WritableReg.fromReg(r1);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // SCVTF S1, W0
    try emit(.{ .scvtf_w_to_s = .{
        .dst = wr1,
        .src = r0,
    } }, &buffer);
    const scvtf_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x1E220001), scvtf_insn);

    // FCVTZS W0, S1
    buffer.data.clearRetainingCapacity();
    try emit(.{ .fcvtzs_s_to_w = .{
        .dst = wr0,
        .src = r1,
    } }, &buffer);
    const fcvtzs_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x1E380020), fcvtzs_insn);
}

test "emit fneg fabs fmax fmin" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .float);
    const v1 = root.reg.VReg.new(1, .float);
    const v2 = root.reg.VReg.new(2, .float);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // FNEG S0, S1
    try emit(.{ .fneg_s = .{
        .dst = wr0,
        .src = r1,
    } }, &buffer);
    const fneg_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x1E214020), fneg_insn);

    // FABS D0, D1
    buffer.data.clearRetainingCapacity();
    try emit(.{ .fabs_d = .{
        .dst = wr0,
        .src = r1,
    } }, &buffer);
    const fabs_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x1E60C020), fabs_insn);

    // FMAX S0, S1, S2
    buffer.data.clearRetainingCapacity();
    try emit(.{ .fmax_s = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } }, &buffer);
    const fmax_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x1E224820), fmax_insn);

    // FMIN D0, D1, D2
    buffer.data.clearRetainingCapacity();
    try emit(.{ .fmin_d = .{
        .dst = wr0,
        .src1 = r1,
        .src2 = r2,
    } }, &buffer);
    const fmin_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x1E625820), fmin_insn);
}

// === Tests for Exclusive Access Instructions ===

test "emit ldxr and stxr word" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);
    const wr2 = root.reg.WritableReg.fromReg(r2);

    // LDXR W0, [X1] - 32-bit
    try emit(.{ .ldxr_w = .{
        .dst = wr0,
        .base = r1,
    } }, &buffer);
    const ldxr_w_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // size=10 (word) + 001000 + 0 + 1 (L) + 0 + 11111 + 0 + 11111 + X1 + X0
    try testing.expectEqual(@as(u32, 0x885F7C20), ldxr_w_insn);

    // STXR W2, W0, [X1] - 32-bit
    buffer.data.clearRetainingCapacity();
    try emit(.{ .stxr_w = .{
        .status = wr2,
        .src = r0,
        .base = r1,
    } }, &buffer);
    const stxr_w_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // size=10 + 001000 + 0 + 0 (L) + 0 + W2(status) + 0 + 11111 + X1 + W0
    try testing.expectEqual(@as(u32, 0x8802_7C20), stxr_w_insn);
}

test "emit ldxr and stxr doubleword" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);
    const wr2 = root.reg.WritableReg.fromReg(r2);

    // LDXR X0, [X1] - 64-bit
    try emit(.{ .ldxr_x = .{
        .dst = wr0,
        .base = r1,
    } }, &buffer);
    const ldxr_x_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // size=11 (doubleword) + rest same as word
    try testing.expectEqual(@as(u32, 0xC85F7C20), ldxr_x_insn);

    // STXR W2, X0, [X1] - 64-bit
    buffer.data.clearRetainingCapacity();
    try emit(.{ .stxr_x = .{
        .status = wr2,
        .src = r0,
        .base = r1,
    } }, &buffer);
    const stxr_x_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0xC8027C20), stxr_x_insn);
}

test "emit ldxrb ldxrh stxrb stxrh" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);
    const wr2 = root.reg.WritableReg.fromReg(r2);

    // LDXRB W0, [X1]
    try emit(.{ .ldxrb = .{
        .dst = wr0,
        .base = r1,
    } }, &buffer);
    const ldxrb_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // size=00 (byte), o0=0
    try testing.expectEqual(@as(u32, 0x085F7C20), ldxrb_insn);

    // LDXRH W0, [X1]
    buffer.data.clearRetainingCapacity();
    try emit(.{ .ldxrh = .{
        .dst = wr0,
        .base = r1,
    } }, &buffer);
    const ldxrh_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // size=01 (halfword), o0=0
    try testing.expectEqual(@as(u32, 0x485F7C20), ldxrh_insn);

    // STXRB W2, W0, [X1]
    buffer.data.clearRetainingCapacity();
    try emit(.{ .stxrb = .{
        .status = wr2,
        .src = r0,
        .base = r1,
    } }, &buffer);
    const stxrb_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x08027C20), stxrb_insn);

    // STXRH W2, W0, [X1]
    buffer.data.clearRetainingCapacity();
    try emit(.{ .stxrh = .{
        .status = wr2,
        .src = r0,
        .base = r1,
    } }, &buffer);
    const stxrh_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x48027C20), stxrh_insn);
}

test "emit ldaxr and stlxr with acquire/release" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);
    const wr2 = root.reg.WritableReg.fromReg(r2);

    // LDAXR W0, [X1] - acquire (o0=1)
    try emit(.{ .ldaxr_w = .{
        .dst = wr0,
        .base = r1,
    } }, &buffer);
    const ldaxr_w_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x885FFC20), ldaxr_w_insn);

    // LDAXR X0, [X1] - acquire 64-bit (o0=1)
    buffer.data.clearRetainingCapacity();
    try emit(.{ .ldaxr_x = .{
        .dst = wr0,
        .base = r1,
    } }, &buffer);
    const ldaxr_x_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0xC85FFC20), ldaxr_x_insn);

    // STLXR W2, W0, [X1] - release (o0=1)
    buffer.data.clearRetainingCapacity();
    try emit(.{ .stlxr_w = .{
        .status = wr2,
        .src = r0,
        .base = r1,
    } }, &buffer);
    const stlxr_w_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0x8802FC20), stlxr_w_insn);

    // STLXR W2, X0, [X1] - release 64-bit (o0=1)
    buffer.data.clearRetainingCapacity();
    try emit(.{ .stlxr_x = .{
        .status = wr2,
        .src = r0,
        .base = r1,
    } }, &buffer);
    const stlxr_x_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0xC802FC20), stlxr_x_insn);
}

// === Tests for Atomic Operations (ARMv8.1-A LSE) ===

test "emit ldadd atomic operations" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LDADD W0, W1, [X2] - 32-bit no ordering
    try emit(.{ .ldadd = .{
        .dst = wr0,
        .src = r1,
        .base = r2,
        .size = .size32,
    } }, &buffer);
    const ldadd_w_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // size=0 + 111000 + AR=00 + 1 + Rs=X1 + opc=000 + 00 + X2 + X0
    try testing.expectEqual(@as(u32, 0xB8210040), ldadd_w_insn);

    // LDADD X0, X1, [X2] - 64-bit no ordering
    buffer.data.clearRetainingCapacity();
    try emit(.{ .ldadd = .{
        .dst = wr0,
        .src = r1,
        .base = r2,
        .size = .size64,
    } }, &buffer);
    const ldadd_x_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // size=1
    try testing.expectEqual(@as(u32, 0xF8210040), ldadd_x_insn);

    // LDADDA W0, W1, [X2] - acquire
    buffer.data.clearRetainingCapacity();
    try emit(.{ .ldadda = .{
        .dst = wr0,
        .src = r1,
        .base = r2,
        .size = .size32,
    } }, &buffer);
    const ldadda_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // AR=10 (acquire)
    try testing.expectEqual(@as(u32, 0xB8A10040), ldadda_insn);

    // LDADDAL X0, X1, [X2] - acquire-release
    buffer.data.clearRetainingCapacity();
    try emit(.{ .ldaddal = .{
        .dst = wr0,
        .src = r1,
        .base = r2,
        .size = .size64,
    } }, &buffer);
    const ldaddal_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // AR=11 (acquire-release)
    try testing.expectEqual(@as(u32, 0xF8E10040), ldaddal_insn);

    // LDADDL W0, W1, [X2] - release
    buffer.data.clearRetainingCapacity();
    try emit(.{ .ldaddl = .{
        .dst = wr0,
        .src = r1,
        .base = r2,
        .size = .size32,
    } }, &buffer);
    const ldaddl_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // AR=01 (release)
    try testing.expectEqual(@as(u32, 0xB8610040), ldaddl_insn);
}

test "emit ldclr ldset ldeor atomic operations" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);
    const wr0 = root.reg.WritableReg.fromReg(r0);

    // LDCLR X0, X1, [X2] - clear bits
    try emit(.{ .ldclr = .{
        .dst = wr0,
        .src = r1,
        .base = r2,
        .size = .size64,
    } }, &buffer);
    const ldclr_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // opc=001 for LDCLR
    try testing.expectEqual(@as(u32, 0xF8211040), ldclr_insn);

    // LDSET X0, X1, [X2] - set bits
    buffer.data.clearRetainingCapacity();
    try emit(.{ .ldset = .{
        .dst = wr0,
        .src = r1,
        .base = r2,
        .size = .size64,
    } }, &buffer);
    const ldset_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // opc=011 for LDSET
    try testing.expectEqual(@as(u32, 0xF8213040), ldset_insn);

    // LDEOR X0, X1, [X2] - XOR bits
    buffer.data.clearRetainingCapacity();
    try emit(.{ .ldeor = .{
        .dst = wr0,
        .src = r1,
        .base = r2,
        .size = .size64,
    } }, &buffer);
    const ldeor_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // opc=010 for LDEOR
    try testing.expectEqual(@as(u32, 0xF8212040), ldeor_insn);
}

test "emit cas compare and swap" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    const v0 = root.reg.VReg.new(0, .int);
    const v1 = root.reg.VReg.new(1, .int);
    const v2 = root.reg.VReg.new(2, .int);
    const r0 = Reg.fromVReg(v0);
    const r1 = Reg.fromVReg(v1);
    const r2 = Reg.fromVReg(v2);

    // CAS W0, W1, [X2] - 32-bit no ordering
    try emit(.{ .cas = .{
        .compare = r0,
        .src = r1,
        .base = r2,
        .size = .size32,
    } }, &buffer);
    const cas_w_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // size=10 + 001010001 + Rs=W1 + 0 + 11111 + X2 + W0
    try testing.expectEqual(@as(u32, 0x88A17C40), cas_w_insn);

    // CAS X0, X1, [X2] - 64-bit no ordering
    buffer.data.clearRetainingCapacity();
    try emit(.{ .cas = .{
        .compare = r0,
        .src = r1,
        .base = r2,
        .size = .size64,
    } }, &buffer);
    const cas_x_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // size=11
    try testing.expectEqual(@as(u32, 0xC8A17C40), cas_x_insn);

    // CASA W0, W1, [X2] - acquire
    buffer.data.clearRetainingCapacity();
    try emit(.{ .casa = .{
        .compare = r0,
        .src = r1,
        .base = r2,
        .size = .size32,
    } }, &buffer);
    const casa_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // L=1 for acquire
    try testing.expectEqual(@as(u32, 0x88E17C40), casa_insn);

    // CASAL X0, X1, [X2] - acquire-release
    buffer.data.clearRetainingCapacity();
    try emit(.{ .casal = .{
        .compare = r0,
        .src = r1,
        .base = r2,
        .size = .size64,
    } }, &buffer);
    const casal_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // L=1 and o0=1 for acquire-release
    try testing.expectEqual(@as(u32, 0xC8E1FC40), casal_insn);

    // CASL W0, W1, [X2] - release
    buffer.data.clearRetainingCapacity();
    try emit(.{ .casl = .{
        .compare = r0,
        .src = r1,
        .base = r2,
        .size = .size32,
    } }, &buffer);
    const casl_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // o0=1 for release
    try testing.expectEqual(@as(u32, 0x88A1FC40), casl_insn);
}

// === Tests for Memory Barriers ===

test "emit memory barriers" {
    var buffer = buffer_mod.MachBuffer.init(testing.allocator);
    defer buffer.deinit();

    // DMB ISH - inner shareable
    try emit(.{ .dmb = .{
        .option = .ish,
    } }, &buffer);
    const dmb_ish_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // 11010101000000110011 + CRm=1011 + 10111111
    try testing.expectEqual(@as(u32, 0xD5033BBF), dmb_ish_insn);

    // DMB SY - full system
    buffer.data.clearRetainingCapacity();
    try emit(.{ .dmb = .{
        .option = .sy,
    } }, &buffer);
    const dmb_sy_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // CRm=1111
    try testing.expectEqual(@as(u32, 0xD5033FBF), dmb_sy_insn);

    // DSB ISH
    buffer.data.clearRetainingCapacity();
    try emit(.{ .dsb = .{
        .option = .ish,
    } }, &buffer);
    const dsb_ish_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // Same as DMB but with different op2 bits
    try testing.expectEqual(@as(u32, 0xD5033B9F), dsb_ish_insn);

    // DSB SY
    buffer.data.clearRetainingCapacity();
    try emit(.{ .dsb = .{
        .option = .sy,
    } }, &buffer);
    const dsb_sy_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    try testing.expectEqual(@as(u32, 0xD5033F9F), dsb_sy_insn);

    // ISB
    buffer.data.clearRetainingCapacity();
    try emit(.{ .isb = {} }, &buffer);
    const isb_insn = std.mem.bytesToValue(u32, buffer.data.items[0..4]);
    // CRm=1111 + 11111111
    try testing.expectEqual(@as(u32, 0xD5033FDF), isb_insn);
}

/// Vector ADD (NEON): ADD Vd.T, Vn.T, Vm.T
/// Encoding: Q|0|0|01110|size|1|Rm|100001|Rn|Rd
fn emitVecAdd(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b0 << 28) |
        (0b01110 << 23) |
        (@as(u32, size) << 21) |
        (0b1 << 20) |
        (@as(u32, rm) << 16) |
        (0b100001 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// Vector SUB (NEON): SUB Vd.T, Vn.T, Vm.T
/// Encoding: Q|0|1|01110|size|1|Rm|100001|Rn|Rd
fn emitVecSub(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b1 << 28) |
        (0b01110 << 23) |
        (@as(u32, size) << 21) |
        (0b1 << 20) |
        (@as(u32, rm) << 16) |
        (0b100001 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// Vector MUL (NEON): MUL Vd.T, Vn.T, Vm.T
/// Encoding: Q|0|0|01110|size|1|Rm|100111|Rn|Rd
fn emitVecMul(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b0 << 28) |
        (0b01110 << 23) |
        (@as(u32, size) << 21) |
        (0b1 << 20) |
        (@as(u32, rm) << 16) |
        (0b100111 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// Vector CMEQ (compare equal): CMEQ Vd.T, Vn.T, Vm.T
/// Encoding: Q|1|0|01110|size|1|Rm|100011|Rn|Rd
fn emitVecCmeq(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (@as(u32, q) << 30) |
        (0b1 << 29) |
        (0b0 << 28) |
        (0b01110 << 23) |
        (@as(u32, size) << 21) |
        (0b1 << 20) |
        (@as(u32, rm) << 16) |
        (0b100011 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// Vector CMGT (compare greater than, signed): CMGT Vd.T, Vn.T, Vm.T
/// Encoding: Q|0|0|01110|size|1|Rm|001101|Rn|Rd
fn emitVecCmgt(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b0 << 28) |
        (0b01110 << 23) |
        (@as(u32, size) << 21) |
        (0b1 << 20) |
        (@as(u32, rm) << 16) |
        (0b001101 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// Vector CMGE (compare greater or equal, signed): CMGE Vd.T, Vn.T, Vm.T
/// Encoding: Q|0|0|01110|size|1|Rm|001111|Rn|Rd
fn emitVecCmge(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b0 << 28) |
        (0b01110 << 23) |
        (@as(u32, size) << 21) |
        (0b1 << 20) |
        (@as(u32, rm) << 16) |
        (0b001111 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// Vector AND (bitwise): AND Vd.16B, Vn.16B, Vm.16B
/// Encoding: 0|Q|0|01110|00|1|Rm|000111|Rn|Rd (Q=1 for 128-bit)
fn emitVecAnd(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b1 << 30) | // Q=1 for 128-bit
        (0b0 << 29) |
        (0b01110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b000111 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// Vector ORR (bitwise OR): ORR Vd.16B, Vn.16B, Vm.16B
/// Encoding: 0|Q|0|01110|10|1|Rm|000111|Rn|Rd
fn emitVecOrr(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b1 << 30) | // Q=1 for 128-bit
        (0b0 << 29) |
        (0b01110 << 24) |
        (0b10 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b000111 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// Vector EOR (bitwise XOR): EOR Vd.16B, Vn.16B, Vm.16B
/// Encoding: 0|Q|1|01110|00|1|Rm|000111|Rn|Rd
fn emitVecEor(dst: Reg, src1: Reg, src2: Reg, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b1 << 30) | // Q=1 for 128-bit
        (0b1 << 29) |
        (0b01110 << 24) |
        (0b00 << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b000111 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// Vector FADD (FP add): FADD Vd.T, Vn.T, Vm.T
/// Encoding: 0|Q|0|01110|0|sz|1|Rm|110101|Rn|Rd
/// sz: 0 for .2s/.4s, 1 for .2d
fn emitVecFadd(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();

    // sz bit: 0 for single, 1 for double
    const sz: u1 = switch (vec_size) {
        .s2, .s4 => 0,
        .d2 => 1,
        else => unreachable, // Only .2s/.4s/.2d valid for FP
    };

    const insn: u32 = (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b01110 << 24) |
        (0b0 << 23) |
        (@as(u32, sz) << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b110101 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// Vector FSUB (FP subtract): FSUB Vd.T, Vn.T, Vm.T
/// Encoding: 0|Q|0|01110|1|sz|1|Rm|110101|Rn|Rd
fn emitVecFsub(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();

    const sz: u1 = switch (vec_size) {
        .s2, .s4 => 0,
        .d2 => 1,
        else => unreachable,
    };

    const insn: u32 = (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b01110 << 24) |
        (0b1 << 23) | // U=1 for FSUB
        (@as(u32, sz) << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b110101 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// Vector FMUL (FP multiply): FMUL Vd.T, Vn.T, Vm.T
/// Encoding: 0|Q|1|01110|0|sz|1|Rm|110111|Rn|Rd
fn emitVecFmul(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();

    const sz: u1 = switch (vec_size) {
        .s2, .s4 => 0,
        .d2 => 1,
        else => unreachable,
    };

    const insn: u32 = (@as(u32, q) << 30) |
        (0b1 << 29) | // bit 29 = 1 for FMUL
        (0b01110 << 24) |
        (0b0 << 23) |
        (@as(u32, sz) << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b110111 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// Vector FDIV (FP divide): FDIV Vd.T, Vn.T, Vm.T
/// Encoding: 0|Q|1|01110|1|sz|1|Rm|111111|Rn|Rd
fn emitVecFdiv(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();

    const sz: u1 = switch (vec_size) {
        .s2, .s4 => 0,
        .d2 => 1,
        else => unreachable,
    };

    const insn: u32 = (@as(u32, q) << 30) |
        (0b1 << 29) |
        (0b01110 << 24) |
        (0b1 << 23) | // U=1 for FDIV
        (@as(u32, sz) << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b111111 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ADDV (add across vector): ADDV Vd, Vn.T
/// Encoding: 0|Q|0|01110|size|11000|110110|Rn|Rd
fn emitAddv(dst: Reg, src: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b11000 << 17) |
        (0b110110 << 11) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SMINV (signed minimum across vector): SMINV Vd, Vn.T
/// Encoding: 0|Q|0|01110|size|11000|110010|Rn|Rd
fn emitSminv(dst: Reg, src: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b11000 << 17) |
        (0b110010 << 11) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SMAXV (signed maximum across vector): SMAXV Vd, Vn.T
/// Encoding: 0|Q|0|01110|size|11000|110100|Rn|Rd
fn emitSmaxv(dst: Reg, src: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b11000 << 17) |
        (0b110100 << 11) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UMINV (unsigned minimum across vector): UMINV Vd, Vn.T
/// Encoding: 0|Q|1|01110|size|11000|110010|Rn|Rd
fn emitUminv(dst: Reg, src: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b1 << 29) | // U=1 for unsigned
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b11000 << 17) |
        (0b110010 << 11) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UMAXV (unsigned maximum across vector): UMAXV Vd, Vn.T
/// Encoding: 0|Q|1|01110|size|11000|110100|Rn|Rd
fn emitUmaxv(dst: Reg, src: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b1 << 29) | // U=1 for unsigned
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b11000 << 17) |
        (0b110100 << 11) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ZIP1 (zip vectors, primary): ZIP1 Vd.T, Vn.T, Vm.T
/// Encoding: 0|Q|0|01110|size|0|Rm|001110|Rn|Rd
fn emitZip1(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b0 << 21) |
        (@as(u32, rm) << 16) |
        (0b001110 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ZIP2 (zip vectors, secondary): ZIP2 Vd.T, Vn.T, Vm.T
/// Encoding: 0|Q|0|01110|size|0|Rm|011110|Rn|Rd
fn emitZip2(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b0 << 21) |
        (@as(u32, rm) << 16) |
        (0b011110 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UZP1 (unzip vectors, primary): UZP1 Vd.T, Vn.T, Vm.T
/// Encoding: 0|Q|0|01110|size|0|Rm|000110|Rn|Rd
fn emitUzp1(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b0 << 21) |
        (@as(u32, rm) << 16) |
        (0b000110 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UZP2 (unzip vectors, secondary): UZP2 Vd.T, Vn.T, Vm.T
/// Encoding: 0|Q|0|01110|size|0|Rm|010110|Rn|Rd
fn emitUzp2(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b0 << 21) |
        (@as(u32, rm) << 16) |
        (0b010110 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// TRN1 (transpose vectors, primary): TRN1 Vd.T, Vn.T, Vm.T
/// Encoding: 0|Q|0|01110|size|0|Rm|001010|Rn|Rd
fn emitTrn1(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b0 << 21) |
        (@as(u32, rm) << 16) |
        (0b001010 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// TRN2 (transpose vectors, secondary): TRN2 Vd.T, Vn.T, Vm.T
/// Encoding: 0|Q|0|01110|size|0|Rm|011010|Rn|Rd
fn emitTrn2(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b0 << 21) |
        (@as(u32, rm) << 16) |
        (0b011010 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// LD1 (load single structure, one register): LD1 {Vt.T}, [Xn]
/// Encoding: 0|Q|0011010|L|0|00000|opcode|size|Rn|Rt
/// L=1 for load, opcode=0111 for single register
fn emitLd1(dst: Reg, addr: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(dst);
    const rn = hwEnc(addr);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b0011010 << 23) |
        (0b1 << 22) | // L=1 for load
        (0b0 << 21) |
        (0b00000 << 16) |
        (0b0111 << 12) | // opcode for single register
        (@as(u32, size) << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rt);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// ST1 (store single structure, one register): ST1 {Vt.T}, [Xn]
/// Encoding: 0|Q|0011010|L|0|00000|opcode|size|Rn|Rt
/// L=0 for store, opcode=0111 for single register
fn emitSt1(src: Reg, addr: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rt = hwEnc(src);
    const rn = hwEnc(addr);
    const q = vec_size.qBit();
    const size = vec_size.sizeBits();

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b0011010 << 23) |
        (0b0 << 22) | // L=0 for store
        (0b0 << 21) |
        (0b00000 << 16) |
        (0b0111 << 12) | // opcode for single register
        (@as(u32, size) << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rt);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// INS (insert element from register): INS Vd.T[index], Vn.T[0]
/// Encoding: 0|Q|1|01110000|imm5|0|imm4|1|Rn|Rd
/// imm5 encodes size and destination index, imm4=0000 for source lane 0
fn emitIns(dst: Reg, src: Reg, index: u4, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    // imm5: index << (size_bits + 1) | (1 << size_bits)
    const size_bits: u3 = switch (vec_size) {
        .b8, .b16 => 0,
        .h4, .h8 => 1,
        .s2, .s4 => 2,
        .d2 => 3,
    };
    const imm5 = (@as(u5, index) << (@as(u3, size_bits) + 1)) | (@as(u5, 1) << size_bits);

    const insn: u32 = (0b0 << 31) |
        (0b1 << 30) | // Q=1
        (0b1 << 29) |
        (0b01110000 << 21) |
        (@as(u32, imm5) << 16) |
        (0b0 << 15) |
        (0b0000 << 11) | // imm4=0000 for source lane 0
        (0b1 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// EXT (extract): EXT Vd.16B, Vn.16B, Vm.16B, #imm
/// Encoding: 0|Q|101110|00|0|Rm|0|imm4|0|Rn|Rd
/// Q=1 for 128-bit, imm4 specifies byte position
fn emitExt(dst: Reg, src1: Reg, src2: Reg, imm: u4, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const insn: u32 = (0b0 << 31) |
        (0b1 << 30) | // Q=1 for 128-bit
        (0b101110 << 24) |
        (0b00 << 22) |
        (0b0 << 21) |
        (@as(u32, rm) << 16) |
        (0b0 << 15) |
        (@as(u32, imm) << 11) |
        (0b0 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// DUP (duplicate element): DUP Vd.T, Vn.T[index]
/// Encoding: 0|Q|0|01110000|imm5|0|00001|Rn|Rd
/// imm5 encodes size and source index
fn emitDupElem(dst: Reg, src: Reg, index: u4, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);
    const q = vec_size.qBit();

    // imm5: index << (size_bits + 1) | (1 << size_bits)
    const size_bits: u3 = switch (vec_size) {
        .b8, .b16 => 0,
        .h4, .h8 => 1,
        .s2, .s4 => 2,
        .d2 => 3,
    };
    const imm5 = (@as(u5, index) << (@as(u3, size_bits) + 1)) | (@as(u5, 1) << size_bits);

    const insn: u32 = (0b0 << 31) |
        (@as(u32, q) << 30) |
        (0b0 << 29) |
        (0b01110000 << 21) |
        (@as(u32, imm5) << 16) |
        (0b0 << 15) |
        (0b00001 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SXTL (signed extend long): SXTL Vd.T, Vn.Tb
/// Encoding: 0|Q|0|01111|immh|immb|101001|Rn|Rd
/// immh:immb = shift amount (element width for extend)
fn emitSxtl(dst: Reg, src: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    // immh encodes destination element size
    const immh: u4 = switch (vec_size) {
        .h8 => 0b0001, // 8b -> 8h
        .s4 => 0b0010, // 4h -> 4s
        .d2 => 0b0100, // 2s -> 2d
        else => unreachable,
    };

    const insn: u32 = (0b0 << 31) |
        (0b1 << 30) | // Q=1 for full width result
        (0b0 << 29) |
        (0b01111 << 24) |
        (@as(u32, immh) << 19) |
        (0b000 << 16) | // immb=000
        (0b101001 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UXTL (unsigned extend long): UXTL Vd.T, Vn.Tb
/// Encoding: 0|Q|1|01111|immh|immb|101001|Rn|Rd
fn emitUxtl(dst: Reg, src: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src);

    const immh: u4 = switch (vec_size) {
        .h8 => 0b0001,
        .s4 => 0b0010,
        .d2 => 0b0100,
        else => unreachable,
    };

    const insn: u32 = (0b0 << 31) |
        (0b1 << 30) | // Q=1
        (0b1 << 29) | // U=1 for unsigned
        (0b01111 << 24) |
        (@as(u32, immh) << 19) |
        (0b000 << 16) |
        (0b101001 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// SADDL (signed add long): SADDL Vd.T, Vn.Tb, Vm.Tb
/// Encoding: 0|Q|0|01110|size|1|Rm|000000|Rn|Rd
/// Q=0 for lower half, size encodes source element size
fn emitSaddl(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    // size encodes source element size
    const size: u2 = switch (vec_size) {
        .h8 => 0b00, // 8b + 8b -> 8h
        .s4 => 0b01, // 4h + 4h -> 4s
        .d2 => 0b10, // 2s + 2s -> 2d
        else => unreachable,
    };

    const insn: u32 = (0b0 << 31) |
        (0b0 << 30) | // Q=0 for lower half
        (0b0 << 29) | // U=0 for signed
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b000000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}

/// UADDL (unsigned add long): UADDL Vd.T, Vn.Tb, Vm.Tb
/// Encoding: 0|Q|1|01110|size|1|Rm|000000|Rn|Rd
fn emitUaddl(dst: Reg, src1: Reg, src2: Reg, vec_size: VectorSize, buffer: *buffer_mod.MachBuffer) !void {
    const rd = hwEnc(dst);
    const rn = hwEnc(src1);
    const rm = hwEnc(src2);

    const size: u2 = switch (vec_size) {
        .h8 => 0b00,
        .s4 => 0b01,
        .d2 => 0b10,
        else => unreachable,
    };

    const insn: u32 = (0b0 << 31) |
        (0b0 << 30) | // Q=0
        (0b1 << 29) | // U=1 for unsigned
        (0b01110 << 24) |
        (@as(u32, size) << 22) |
        (0b1 << 21) |
        (@as(u32, rm) << 16) |
        (0b000000 << 10) |
        (@as(u32, rn) << 5) |
        @as(u32, rd);

    const bytes = std.mem.toBytes(insn);
    try buffer.put(&bytes);
}
