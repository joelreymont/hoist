---
title: Lazy active compaction
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T22:14:33.935943+01:00\\\"\""
closed-at: "2026-02-17T22:17:44.773435+01:00"
close-reason: "discarded: failed gate, large(100) regressed +6.50%"
---

Context: src/regalloc/linear_scan.zig expireOldIntervals shifts active list on every range and creates O(n^2) memmove pressure in regalloc stage. Cause: eager front compaction each iteration. Fix: track active_start head index, free expired intervals by advancing head, compact only when head growth threshold is hit, keep active sorted semantics for spill/insert. Verify: zig build test -j1 and same-tree A/B with perf gate; keep only if >=5% retained gain and no regressions.
