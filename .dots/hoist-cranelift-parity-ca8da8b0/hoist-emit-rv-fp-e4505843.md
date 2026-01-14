---
title: Emit rv fp
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.412984+02:00"
---

Files: src/backends/riscv64/emit.zig (new), src/backends/riscv64/inst.zig (new)
Root cause: RV64F/D/A encoders missing.
Fix: add encoders for FP and atomic insts.
Why: FP/atomic ops correctness.
Deps: Add rv fp, Emit rv base.
Verify: FP/atomic encoding tests.
