---
title: Profile phase costs
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T11:42:00.932935+01:00\\\"\""
closed-at: "2026-02-17T11:49:18.482649+01:00"
close-reason: implemented stage timers, bench breakdown, verified via zig build test+bench
---

Measure compile pipeline stage timings in src/codegen/compile.zig (verify/legalize/opt/lower/regalloc/emit) using low-overhead timers and bench harness. Cause: hotspots not quantified per stage. Fix: add explicit timing counters and emit benchmark breakdown. Why: target only dominating stages.
