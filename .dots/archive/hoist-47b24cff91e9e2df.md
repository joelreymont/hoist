---
title: Add irsub_imm lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.832179+02:00"
closed-at: "2026-01-06T08:53:23.427839+02:00"
---

File: compile.zig line ~810. Lower irsub_imm (reverse subtract) to SUB Xd, Xn, #imm with reversed operand order. Uses existing sub_imm inst variant at inst.zig:98-103. Pattern: SUB dst, #imm, src (emulated as NEG+ADD if needed). ARM64: SUB or NEG+ADD. Effort: 25 min.
