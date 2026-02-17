---
title: Reserve VCode capacity
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T22:28:21.030589+01:00\\\"\""
closed-at: "2026-02-17T22:31:29.196289+01:00"
close-reason: "discarded: failed gate, large(100) regressed +18.42%"
---

Context: lower stage dominates large compile cost and benchmark churn shows frequent remaps during compile. Cause: VCode arrays grow incrementally without IR-size hints. Fix: estimate block/inst/param counts upfront in lowerFunctionWithFeatures and reserve VCode capacities (with thresholded insn slack) before lowering. Verify: zig build test -j1 and same-tree A/B gate; keep only if >=5% retained gains and no regressions.
