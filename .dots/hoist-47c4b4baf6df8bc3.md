---
title: Implement dynamic_stack_store opcode
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:27:11.577834+02:00"
closed-at: "2026-01-07T06:54:10.790576+02:00"
---

File: src/backends/aarch64/lower.isle - Add lowering for dynamic_stack_store (store to dynamically allocated stack). Pattern: STR Xs, [X<dyn_sp>, #offset]. Compute effective address (dynamic_sp + offset), emit store instruction. Dual of dynamic_stack_load. Dependencies: dynamic stack pointer tracking. Instruction: STR with dynamic base register.
