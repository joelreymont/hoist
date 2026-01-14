---
title: Opt parity
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:06:32.615114+02:00\""
closed-at: "2026-01-14T15:42:57.194322+02:00"
close-reason: split into small dots under hoist-cranelift-parity
---

Context: /Users/joel/Work/hoist/docs/feature_gap_analysis.md:106-116 (CCMP, load/store combine, cost model, vector shuffle), /Users/joel/Work/hoist/docs/egraph-design.md:146-154 (e-graph plan), /Users/joel/Work/hoist/docs/missing-optimization-passes.md:61-76 (Cranelift egraph rules). Root cause: missing or partial advanced optimizations. Fix: implement e-graph optimizer, load/store combine, vector shuffle improvements, CCMP lowering. Why: parity with Cranelift optimization capabilities.
