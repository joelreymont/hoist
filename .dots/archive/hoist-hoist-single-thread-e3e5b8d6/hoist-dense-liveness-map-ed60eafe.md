---
title: Dense liveness map
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T17:42:02.610638+01:00\\\"\""
closed-at: "2026-02-17T17:45:16.917734+01:00"
close-reason: completed
---

Full context: src/regalloc/liveness.zig:94-282 uses AutoHashMap(u32,u32) for vreg->range in hot noteRangeUse/getRange path. Cause: hash lookups dominate large single-block workloads with thousands of vregs. Fix: replace with dense u32 index table with sentinel, retain O(1) direct indexing, update all accessors and tests; prove via zig build test + A/B bench-compare.
