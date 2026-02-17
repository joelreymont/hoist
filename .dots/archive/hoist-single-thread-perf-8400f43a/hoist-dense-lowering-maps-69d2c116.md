---
title: Dense lowering maps
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T20:38:18.781678+01:00\""
closed-at: "2026-02-17T21:57:28.907268+01:00"
close-reason: "discarded: previously measured dense lowering maps regressed small/medium benchmarks under gate"
blocks:
  - hoist-rewrite-emit-fusion-d1e20524
---

Context: src/codegen/compile.zig:1636-1935, 5783-6395. Cause: lowering uses AutoHashMap lookups for block mapping/origin tracking on hot paths; small funcs need low overhead, large funcs need dense fast lookups. Fix: introduce size-gated dense tables for block and vreg-origin mapping on large functions while preserving small-function fast path. Why: lower-stage speedup without regressing micro workloads. Verify: zig build test && bench-gate; require >=5% retained gains and zero regressions.
