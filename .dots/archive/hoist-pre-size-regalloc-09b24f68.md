---
title: Pre-size regalloc maps
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T14:42:19.961282+01:00\\\"\""
closed-at: "2026-02-17T14:44:33.193378+01:00"
close-reason: "Discarded: perf gate/history did not show >=5% positive improvement."
---

Full context: src/regalloc/linear_scan.zig allocateInto currently reuses maps but may still remap heavily as live-range counts grow by function size; cause likely map growth churn in vreg_to_preg/vreg_to_spill; fix by ensuring capacity from liveness range count before allocation; proof via zig build bench-gate -Dbench-repeat=5 and compare /tmp/hoist-bench-report.json; keep only if >=5% positive improvement in key compile metrics.
