---
title: Add abs(-x) = abs(x) simplification
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T18:20:24.106276+02:00"
closed-at: "2026-01-03T18:21:12.570582+02:00"
---

File: src/codegen/opts/instcombine.zig - In combineUnary for iabs: if arg is ineg(x), replace with iabs(x). Absolute value of negation.
