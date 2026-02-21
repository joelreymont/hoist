---
title: 2x perf loop v2
status: active
priority: 1
issue-type: task
created-at: "\"2026-02-21T21:04:55.043798+01:00\""
---

Context: compile large(5000) stage medians lower/regalloc/rewrite/emit dominate; objective: reach 2x compile-time target vs loop baseline with strict no-regression gate and >=5% retained gains; verification: repeat-9 logs + bench-compare + bench-budget(2x).
