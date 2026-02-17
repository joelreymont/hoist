---
title: Hoist single-thread perf drive
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-17T17:42:02.605236+01:00\""
closed-at: "2026-02-17T17:52:09.997387+01:00"
close-reason: completed
---

Full context: compile_large(5000) stage profile shows lower/regalloc dominate single-thread latency; objective is >=5% retained uplift per landed change with no perf regressions; enforce same-tree A/B via bench-log+bench-compare and keep history. Cause: remaining hot paths in liveness, rewrite, regalloc setup. Fix: execute child dots in dependency order and close only with test+gate proof.
