---
title: Add x64 regalloc
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.758711+02:00"
---

Files: src/backends/x64/inst.zig:12-93
Root cause: x64 backend lacks regalloc2 bridge and operands.
Fix: add regalloc bridge and use getOperands for x64.
Why: regalloc2 support for x64.
Deps: Add x64 operands, Wire regalloc2.
Verify: x64 allocation tests.
