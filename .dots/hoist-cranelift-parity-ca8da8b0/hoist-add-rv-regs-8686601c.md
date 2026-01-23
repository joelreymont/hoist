---
title: Add rv regs
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.389467+02:00\""
closed-at: "2026-01-23T10:51:28.549591+02:00"
---

Files: docs/architecture/06-backends.md:11-18, src/backends/x64/regs.zig:1-60
Root cause: riscv64 backend missing register definitions.
Fix: add src/backends/riscv64/regs.zig with GPR/FPR definitions and helpers.
Why: register file needed for backend.
Deps: none.
Verify: add riscv64 reg tests.
