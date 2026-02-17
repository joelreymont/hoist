---
title: Single-thread perf wave
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-17T20:38:00.405146+01:00\""
closed-at: "2026-02-17T21:57:36.247298+01:00"
close-reason: "closed: all child perf opportunities evaluated; none met retained >=5% gain without regressions"
---

Context: src/codegen/compile.zig, src/regalloc/*.zig, src/backends/aarch64/inst.zig. Cause: lower+regalloc dominate large-function compile time (large5000 median total ~2195us). Fix: execute six staged perf dots with strict perf-gate/no-regression enforcement and keep only >=5% gains. Why: deliver significant single-thread throughput improvement with measurable evidence.
