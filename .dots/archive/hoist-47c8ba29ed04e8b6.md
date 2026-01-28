---
title: Add vreg→preg rewriting for Priority 7-11 (Phase 3)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T11:15:02.605077+02:00"
closed-at: "2026-01-07T14:24:51.491906+02:00"
---

File: src/codegen/compile.zig - Add vreg→preg rewriting for remaining ~52 instruction types:

Priority 7 (FP arithmetic - 30 types):
fmov, fmov_imm, fmov_from_gpr, fmov_to_gpr, fadd, fsub, fmul, fdiv, fmadd, fmsub, fneg, fabs, fsqrt, frintn, frintz, frintp, frintm, fmin, fmax, fcmp, fcmp_zero, fcsel, scvtf, ucvtf, fcvtzs, fcvtzu, fcvt_f32_to_f64, fcvt_f64_to_f32, vldr, vstr

Priority 8 (advanced load/store - 12 types):
ldp (already done in Priority 2), ldr_pre, ldr_post, str_pre, str_post, vldp, vstp, popcnt, rev16, rev32, rev64

Priority 9 (saturating arithmetic - 4 types):
sqadd, sqsub, uqadd, uqsub

Priority 11 (sign extension - 6 types):
sxtb, uxtb, sxth, uxth, sxtw, uxtw

Note: ldp/stp already done in Priority 2. Cannot combine instructions in switch cases.
After this phase: 100% vreg→preg rewriting coverage (~130 total types)
