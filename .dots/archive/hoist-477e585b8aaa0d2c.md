---
title: Add x * (1 << y) = x << y pattern
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T18:30:34.109619+02:00"
closed-at: "2026-01-03T18:32:10.561454+02:00"
---

File: src/codegen/opts/instcombine.zig - In combineBinary for imul: if RHS is ishl(1, y), replace with ishl(x, y). Multiply by power-of-2 is shift.
