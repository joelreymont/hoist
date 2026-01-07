---
title: "P2.11e: Vector float conversions (8 rules)"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T09:11:46.541980+02:00"
closed-at: "2026-01-04T09:22:56.172781+02:00"
---

File: src/backends/aarch64/lower.isle. Add fcvt_from_uint, fcvt_from_sint, fcvt_to_uint_sat, fcvt_to_sint_sat for multi_lane 32/64 types. Pattern: (rule -1 (lower (has_type ty @ (multi_lane 32 _) (fcvt_from_uint x @ (value_type (multi_lane 32 _))))) ...). Reference: ~/Work/wasmtime/cranelift/codegen/src/isa/aarch64/lower.isle:656-719. Depends on P2.11b. Est: 2h.
