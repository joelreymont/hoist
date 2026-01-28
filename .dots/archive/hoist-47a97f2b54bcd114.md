---
title: Implement scalar FP arithmetic
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:28.855238+02:00"
closed-at: "2026-01-05T23:27:03.522758+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower fadd/fsub/fmul/fdiv IR opcodes to scalar FP instructions FADD/FSUB/FMUL/FDIV. Implement sqrt → FSQRT, fmin/fmax → FMIN/FMAX. Support f32 and f64. Reference: Cranelift lower.isle FP patterns. Part of Phase 2 core functionality. Estimate: 1 day.
