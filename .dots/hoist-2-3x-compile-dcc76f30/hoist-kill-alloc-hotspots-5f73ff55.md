---
title: Kill alloc hotspots
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T11:42:00.937875+01:00\\\"\""
closed-at: "2026-02-17T11:53:54.165180+01:00"
close-reason: replaced CFG liveness map-of-maps with indexed reusable sets; removed per-compile block_insns map; validated with test+bench
---

Audit and remove per-function allocations in hot compile paths: liveness, lowering, regalloc, egraph setup. files: src/regalloc/liveness.zig, src/codegen/context.zig, src/codegen/compile.zig. Cause: repeated alloc/free churn. Fix: reuse buffers, pre-size arrays, and clear-in-place. Why: reduce allocator overhead and cache misses.
