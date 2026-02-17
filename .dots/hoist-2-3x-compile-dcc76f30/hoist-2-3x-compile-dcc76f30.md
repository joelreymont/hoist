---
title: 2-3x compile perf
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T11:41:50.867979+01:00"
---

Goal: double/triple compile throughput from current benchmark baseline. files: src/codegen/compile.zig, src/regalloc/liveness.zig, src/context.zig, bench/*.zig. Cause: compile still dominated by per-function pipeline costs and residual allocations. Fix: profile, remove hot allocations/state rebuild, and validate with bench deltas. Why: parity with Cranelift throughput and lower compile latency.
