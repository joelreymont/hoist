---
title: Add FP helpers
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-14T10:07:04.954873+02:00\""
closed-at: "2026-01-23T08:51:33.320910+02:00"
---

Full context including:
- Files to modify: src/backends/aarch64/emit.zig:3634
- What to change: add helpers for fmov gpr<->fpr, fcmp_zero, fcsel, ucvtf, fcvtzu; fix scvtf/fcvtzs 64-bit top bits to 0b100.
- Dependencies: none
- Verification: zig build test
