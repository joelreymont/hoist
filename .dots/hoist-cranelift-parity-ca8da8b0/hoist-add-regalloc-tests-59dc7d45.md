---
title: Add regalloc tests
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.764951+02:00\""
closed-at: "2026-01-23T21:35:04.959623+02:00"
---

Files: fuzz/fuzz_regalloc.zig:1-80
Root cause: regalloc fuzzing is minimal and linear-scan only.
Fix: add regalloc2 tests and property-based checks with zcheck.
Why: verify allocator correctness.
Deps: Wire regalloc2.
Verify: zig build test and fuzz step.
