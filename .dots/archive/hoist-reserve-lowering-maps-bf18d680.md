---
title: Reserve lowering maps
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T22:55:53.142018+01:00\\\"\""
closed-at: "2026-02-17T22:59:52.239448+01:00"
close-reason: "discarded: failed gate, large(100)+30.70%"
---

Context: lower stage dominates large compile cost and allocator churn shows repeated remaps in lowering paths. Cause: value_to_reg/block_map/visited maps and RPO vector grow incrementally without capacity hints. Fix: reserve capacities from block/value counts before fill loops in lower.zig. Verify: zig build test -j1 and same-tree A/B gate; keep only if >=5% retained gains and no regressions.
