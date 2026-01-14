---
title: Add rv insts
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.395244+02:00"
---

Files: docs/architecture/06-backends.md:11-18, src/backends/x64/inst.zig:12-93
Root cause: no riscv64 Inst definitions.
Fix: add src/backends/riscv64/inst.zig with RV64I ALU/branch/mem insts and operand types.
Why: lowering needs inst enum.
Deps: Add rv regs.
Verify: inst format tests.
