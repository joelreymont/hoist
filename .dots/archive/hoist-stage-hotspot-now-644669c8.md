---
title: Stage hotspot now
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-18T08:18:01.318773+01:00\""
closed-at: "2026-02-18T08:24:43.980690+01:00"
close-reason: "completed: hotspot confirmed (lower/regalloc/emit); implemented next dot from emit stage"
---

Full context: with retained vreg-origin trim landed in working tree, capture fresh stage-cost profile to pick next >5% single-thread target. Run repeat-9 benchmark log, extract dominant stage medians by size/workload, then create one focused implementation dot and gate with fresh baseline.
