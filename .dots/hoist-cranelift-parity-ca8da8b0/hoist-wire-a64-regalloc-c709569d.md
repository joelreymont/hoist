---
title: Wire a64 regalloc
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.752808+02:00"
---

Files: src/backends/aarch64/isa.zig:247-288
Root cause: compileWithRegalloc2 uses dummy allocations.
Fix: switch compileFunction to real regalloc2 and remove dummy mapping.
Why: correct aarch64 allocation.
Deps: Wire regalloc2.
Verify: aarch64 codegen tests.
