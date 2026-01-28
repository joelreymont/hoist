---
title: "P2.11.3: avg_round patterns blocked"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T14:24:25.629582+02:00"
closed-at: "2026-01-05T16:38:40.475764+02:00"
---

File: src/backends/aarch64/lower.isle - BLOCKED: avg_round requires VecALUOp.Urhadd (unsigned rounding halving add) for I8X16/I16X8/I32X4. Also needs splat_const helper. The I64X2 variant could be implemented with existing helpers (ushr_vec_imm, or_vec, and_vec, add_vec) but not worth adding just one variant. Cranelift:2882-2893. Used in video codecs.
