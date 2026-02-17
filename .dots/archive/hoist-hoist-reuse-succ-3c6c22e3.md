---
title: Hoist reuse succ buffer
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T17:36:22.797274+01:00\\\"\""
closed-at: "2026-02-17T17:39:47.466335+01:00"
close-reason: discarded (<5% median gain; no regressions)
---

Full context: src/codegen/compile.zig:1906-1924 lowerAArch64 allocates/deinits a new ArrayList(BlockIndex) per block while building CFG successors. Cause: per-block allocator churn in lowering hot path. Fix: allocate one successors buffer before block loop and clearRetainingCapacity() per block. Proof: zig build test + same-tree A/B (bench-log + bench-compare, repeat=11), keep only if no regressions and >=5% improvement metric.
