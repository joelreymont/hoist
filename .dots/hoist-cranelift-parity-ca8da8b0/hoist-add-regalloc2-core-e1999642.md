---
title: Add regalloc2 core
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.741176+02:00"
---

Files: src/machinst/regalloc.zig:13-16, src/machinst/regalloc2/*.zig
Root cause: regalloc2 algorithm not implemented.
Fix: implement allocation algorithm with coalescing, spill, reload, and backtracking.
Why: parity with Cranelift regalloc2 quality.
Deps: none.
Verify: regalloc2 unit tests.
