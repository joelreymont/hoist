---
title: "P2.11c: Vector float binary ops (6 rules)"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T09:11:31.184212+02:00"
closed-at: "2026-01-04T09:18:18.003988+02:00"
---

File: src/backends/aarch64/lower.isle. Add fadd, fsub, fmul, fdiv, fmin, fmax for multi_lane types. Pattern: (rule -1 (lower (has_type ty @ (multi_lane _ _) (fadd x y))) (vec_rrr (VecALUOp.Fadd) x y (vector_size ty))). Reference: ~/Work/wasmtime/cranelift/codegen/src/isa/aarch64/lower.isle:412-456. Depends on P2.11b. Est: 1h.
