---
title: Drive 2x3x compile throughput
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:07:40.513097+01:00\""
closed-at: "2026-02-17T14:33:22.470907+01:00"
close-reason: "completed 2x/3x drive cycle: delivered parallel compile throughput + perf gate/budget/history + regalloc/liveness reuse wins; discarded attempted sub-optimizations that violated >=5% net-no-regression rule"
---

Context: build.zig:52, src/codegen/compile.zig:6487, src/regalloc/liveness.zig:355, src/regalloc/linear_scan.zig:300; cause: compile pipeline is dominated by optimize/regalloc and benchmark defaults obscure production throughput; fix: execute a staged optimization program with measurable gates to reach 2x/3x throughput; deps: none; verification: zig build bench-gate -Doptimize=ReleaseFast -Dbench-repeat=5 plus stage-by-stage perf deltas.
