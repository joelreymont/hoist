---
title: Add budget guard thresholds
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.955969+01:00\""
closed-at: "2026-02-17T13:33:49.759826+01:00"
close-reason: added optional budget guards to tools/perf_gate.zig via --budget-reference and --budget-multiplier for key metrics (fib, large5000, int/vector/memory/mixed), with explicit budget miss messages and non-zero PerfBudgetMiss exit; wired build.zig bench-gate options (-Dbench-budget-reference-path, -Dbench-budget-multiplier); verified synthetic breach exits non-zero
---

Context: tools/perf_gate.zig; cause: gate checks only per-run regression and not long-term progress targets; fix: add budget checks for key metrics toward 2x/3x targets with explicit failure messages; deps: Persist perf history json; verification: synthetic budget breach triggers non-zero exit.
