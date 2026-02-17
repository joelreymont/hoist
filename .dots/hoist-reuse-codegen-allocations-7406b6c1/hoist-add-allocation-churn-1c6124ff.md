---
title: Add allocation-churn benchmark
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.890533+01:00"
---

Context: bench/aarch64_perf.zig and profiling scripts; cause: no direct metric for allocator churn regressions; fix: record allocation/free counters during compile loops and report per stage; deps: Persist liveness buffers per context; verification: benchmark output shows lower churn after reuse changes.
