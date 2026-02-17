---
title: Add allocation-churn benchmark
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.890533+01:00\""
closed-at: "2026-02-17T14:07:02.348604+01:00"
close-reason: implemented counting allocator benchmark instrumentation in bench/counting_allocator.zig with churn reporting in compile_fib, compile_large, and aarch64_perf; validated via zig build bench-log and /tmp/hoist-bench.log churn lines
---

Context: bench/aarch64_perf.zig and profiling scripts; cause: no direct metric for allocator churn regressions; fix: record allocation/free counters during compile loops and report per stage; deps: Persist liveness buffers per context; verification: benchmark output shows lower churn after reuse changes.
