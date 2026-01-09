---
title: Test e-graph optimizations
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T07:46:07.363895+02:00\""
closed-at: "2026-01-09T13:37:58.610699+02:00"
---

Write tests for: constant folding, strength reduction, algebraic simplification, CSE via equality saturation. Files: tests/egraph_opt.zig (new), ~350 lines. Verify correctness. ~120 min.
