---
title: Tune default egraph threshold
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T16:01:53.377069+01:00\""
closed-at: "2026-02-17T16:03:41.347963+01:00"
close-reason: "discarded: failed perf gate with multiple regressions; reverted default_egraph_min_complexity"
---

src/codegen/compile.zig default_egraph_min_complexity: increase threshold to skip e-graph on small functions and reduce compile latency; validate with bench-gate A/B and tests; keep only if >=5% positive.
