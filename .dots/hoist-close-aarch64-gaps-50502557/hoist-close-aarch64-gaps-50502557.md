---
title: Close aarch64 gaps
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T14:14:03.081041+02:00"
---

Context: failing AArch64 encode/emit tests in src/backends/aarch64/emit.zig (e.g., ldr/str, SIMD, FP, adr/adrp). Root cause: encoder bitfields, missing emit cases, and stale test expectations vs ARM ARM/assembler. Goal: fix encoders/tests, update docs (docs/feature_gap_analysis.md, docs/COMPLETION_STATUS.md), re-run zig build test.
