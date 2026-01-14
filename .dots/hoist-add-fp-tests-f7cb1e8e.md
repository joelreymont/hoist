---
title: Add FP tests
status: open
priority: 2
issue-type: task
created-at: "2026-01-14T10:07:04.963819+02:00"
---

Full context including:
- Files to modify: src/backends/aarch64/emit.zig:10286
- What to change: add encoding tests for gpr<->fpr FMOV, FCMP #0.0, FCVT f64<->f32, UCVTF, FCVTZU, 64-bit SCVTF/FCVTZS, FRINTN/Z/P/M, FCSEL.
- Dependencies: Add FP helpers, Wire FP emit
- Verification: zig build test
