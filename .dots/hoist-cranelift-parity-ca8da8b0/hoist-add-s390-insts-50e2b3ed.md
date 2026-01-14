---
title: Add s390 insts
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.459593+02:00"
---

Files: docs/architecture/06-backends.md:11-18, src/backends/x64/inst.zig:12-93
Root cause: no s390x Inst definitions.
Fix: add src/backends/s390x/inst.zig with base ALU/branch/mem insts and operand types.
Why: lowering needs inst enum.
Deps: Add s390 regs.
Verify: inst format tests.
