---
title: "P2.5.6: Add ishl patterns for ty_vec128"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T13:20:53.711873+02:00"
closed-at: "2026-01-04T13:34:26.451971+02:00"
---

File: src/backends/aarch64/lower.isle - Add 2 rules: variable shift using vec_rrr VecALUOp.Sshl (prio -1), immediate shift using vec_rr_imm VecALUOp.Shl (prio -2). Cranelift:1548,1553. Depends on P2.5.1.
