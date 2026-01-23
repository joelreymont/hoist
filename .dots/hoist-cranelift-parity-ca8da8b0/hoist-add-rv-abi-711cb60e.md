---
title: Add rv abi
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.430613+02:00\""
closed-at: "2026-01-23T10:57:27.420886+02:00"
---

Files: docs/architecture/06-backends.md:11-18, src/backends/x64/abi.zig:111-187
Root cause: riscv64 ABI not implemented.
Fix: add src/backends/riscv64/abi.zig implementing SysV ABI (arg regs, stack, returns).
Why: correct calling convention.
Deps: Add rv regs.
Verify: ABI tests.
