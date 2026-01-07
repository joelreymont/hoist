---
title: Add iadd_imm lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.828587+02:00"
closed-at: "2026-01-06T08:51:09.027328+02:00"
---

File: compile.zig line ~800. Lower iadd_imm to ADD Xd, Xn, #imm instruction. Uses existing add_imm inst variant at inst.zig:61-66. Extract base value, immediate offset, emit ADD with 12-bit imm. Follows pattern at lower.isle:259. ARM64: ADD Xd, Xn, #imm12. Effort: 20 min.
