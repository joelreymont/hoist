---
title: Dense CFG liveness
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T20:38:18.727663+01:00\\\"\""
closed-at: "2026-02-17T21:45:08.016257+01:00"
close-reason: "discarded: no >=5% gain and perf-gate regression in parallel metric"
---

Context: src/regalloc/liveness.zig:322-626. Cause: CFG liveness fixed-point currently uses AutoHashMap set unions/diffs per block iteration and repeated hash churn. Fix: precompute per-block use/def dense sets, run changed-block worklist with dense bitsets, and build live ranges from dense data without per-iteration maps. Why: cut lower/regalloc front-end time on multi-block workloads. Verify: zig build test && zig build bench-gate -Dbench-repeat=5 with >=5% improvement on tracked large/serial metrics and zero gate regressions.
