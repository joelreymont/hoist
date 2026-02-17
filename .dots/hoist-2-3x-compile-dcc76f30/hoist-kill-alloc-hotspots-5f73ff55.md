---
title: Kill alloc hotspots
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T11:42:00.937875+01:00"
---

Audit and remove per-function allocations in hot compile paths: liveness, lowering, regalloc, egraph setup. files: src/regalloc/liveness.zig, src/codegen/context.zig, src/codegen/compile.zig. Cause: repeated alloc/free churn. Fix: reuse buffers, pre-size arrays, and clear-in-place. Why: reduce allocator overhead and cache misses.
