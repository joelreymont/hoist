---
title: Dense regalloc state
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T20:38:18.749564+01:00\\\"\""
closed-at: "2026-02-17T21:50:57.648045+01:00"
close-reason: "discarded: A/B perf-gate regressions and no stable no-regression >=5% gain"
blocks:
  - hoist-dense-cfg-liveness-8bd14ce0
---

Context: src/regalloc/linear_scan.zig:45-670 and src/codegen/compile.zig:6520-6620. Cause: hot allocation paths repeatedly hit AutoHashMap for vreg->preg/spill, hints, and coalesce mates. Fix: move allocator and result hot maps to dense index tables keyed by vreg index with retained-capacity reuse; keep API compatibility at boundaries only. Why: reduce regalloc stage latency and allocator churn. Verify: zig build test && same-tree A/B with bench-compare; keep only >=5% gains and no regressions.
