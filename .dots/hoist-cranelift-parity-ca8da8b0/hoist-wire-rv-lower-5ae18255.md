---
title: Wire rv lower
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.418558+02:00"
---

Files: docs/architecture/06-backends.md:11-18, src/backends/x64/lower.zig:12-55
Root cause: riscv64 lowering missing.
Fix: add src/backends/riscv64/lower.isle and lower.zig for RV64I lowering.
Why: IR->riscv64 lowering.
Deps: Add rv insts.
Verify: lowering tests.
