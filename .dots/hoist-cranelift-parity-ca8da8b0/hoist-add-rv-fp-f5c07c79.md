---
title: Add rv fp
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.401125+02:00\""
closed-at: "2026-01-23T10:51:48.725405+02:00"
---

Files: docs/architecture/06-backends.md:11-18, src/backends/riscv64/inst.zig (new)
Root cause: RV64F/D/A inst coverage missing.
Fix: add FP and atomic inst variants to riscv64 Inst.
Why: parity with Cranelift riscv64 backend.
Deps: Add rv insts.
Verify: inst format tests.
