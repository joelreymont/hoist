---
title: Hoist disable coalesce pass
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T16:54:01.644470+01:00\\\"\""
closed-at: "2026-02-17T16:55:55.019353+01:00"
close-reason: "discarded (perf gate fail: large100 regression +9.84%; no >=5% positive gains)"
---

Full context: src/codegen/compile.zig:6556 unconditionally runs collectCoalescePairs before linear scan. Cause: coalesce candidate + interfere checks may consume notable regalloc time on large functions. Fix: disable coalesce-pair collection in default single-thread compile path and rely on existing peephole dead-move cleanup post-regalloc. Proof: zig build test + bench-gate repeat=11; keep only if >=5% positive gains and no gate regressions.
