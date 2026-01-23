---
title: Wire rv fp
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.424566+02:00\""
closed-at: "2026-01-23T10:56:29.126014+02:00"
---

Files: src/backends/riscv64/lower.isle (new), src/backends/riscv64/inst.zig (new)
Root cause: FP/atomic lowering rules missing.
Fix: add FP and atomic ISLE rules for riscv64.
Why: full feature coverage.
Deps: Add rv fp.
Verify: FP/atomic lowering tests.
