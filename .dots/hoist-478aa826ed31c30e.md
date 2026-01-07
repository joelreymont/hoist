---
title: "P2.11f: Vector integer ops (2 rules)"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T09:11:52.446275+02:00"
closed-at: "2026-01-04T09:19:43.102898+02:00"
---

File: src/backends/aarch64/lower.isle. Add iabs and sqmul_round_sat for multi_lane types. Pattern: (rule -1 (lower (has_type ty @ (multi_lane _ _) (iabs x))) (vec_misc (VecMisc2.Abs) x (vector_size ty))). Reference: ~/Work/wasmtime/cranelift/codegen/src/isa/aarch64/lower.isle:364, 407. Depends on P2.11b. Est: 30min.
