---
title: Speed up liveness analysis
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:07:40.542560+01:00"
---

Context: src/regalloc/liveness.zig:355-520; cause: CFG liveness uses per-block hash maps and per-vreg hash operations in fixed-point loops; fix: move to dense bitsets and indexed storage; deps: Drive 2x3x compile throughput; verification: liveness stage time reduced on large5000 benchmark without semantic regressions.
