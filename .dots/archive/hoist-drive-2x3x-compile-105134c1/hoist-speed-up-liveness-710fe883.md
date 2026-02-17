---
title: Speed up liveness analysis
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:07:40.542560+01:00\""
closed-at: "2026-02-17T14:33:08.771073+01:00"
close-reason: "completed liveness subtree: kept buffer reuse + perf regression guards; discarded dense/bitset/live-range variants that failed >=5% net-no-regression policy"
---

Context: src/regalloc/liveness.zig:355-520; cause: CFG liveness uses per-block hash maps and per-vreg hash operations in fixed-point loops; fix: move to dense bitsets and indexed storage; deps: Drive 2x3x compile throughput; verification: liveness stage time reduced on large5000 benchmark without semantic regressions.
