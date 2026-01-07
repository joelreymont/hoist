---
title: Add imul_imm lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.839715+02:00"
closed-at: "2026-01-06T08:55:30.622175+02:00"
---

File: compile.zig. Lower imul_imm opcode. Extract value and immediate, call MOV+MUL helper. Special case power-of-2 immediates to LSL for optimization. Depends on: MOV+MUL pattern infrastructure. ARM64: MOV+MUL or LSL for powers of 2. Effort: 20 min.
