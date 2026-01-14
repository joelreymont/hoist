---
title: Wire FP emit
status: open
priority: 2
issue-type: task
created-at: "2026-01-14T10:07:04.959726+02:00"
---

Full context including:
- Files to modify: src/backends/aarch64/emit.zig:199
- What to change: add switch cases for fmov/fmov_imm/fmov_from_gpr/fmov_to_gpr/fcmp/fcmp_zero/fcsel/scvtf/ucvtf/fcvtzs/fcvtzu/fcvt_f32_to_f64/fcvt_f64_to_f32/frint* using helpers.
- Dependencies: Add FP helpers
- Verification: zig build test
