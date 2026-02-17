---
title: Drive 2x3x compile throughput
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:07:40.513097+01:00"
---

Context: build.zig:52, src/codegen/compile.zig:6487, src/regalloc/liveness.zig:355, src/regalloc/linear_scan.zig:300; cause: compile pipeline is dominated by optimize/regalloc and benchmark defaults obscure production throughput; fix: execute a staged optimization program with measurable gates to reach 2x/3x throughput; deps: none; verification: zig build bench-gate -Doptimize=ReleaseFast -Dbench-repeat=5 plus stage-by-stage perf deltas.
