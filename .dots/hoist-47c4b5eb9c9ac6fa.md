---
title: Implement stack_switch opcode
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:27:31.543205+02:00"
closed-at: "2026-01-07T07:20:43.835826+02:00"
---

File: src/backends/aarch64/lower.isle - Add lowering for stack_switch (switch between fiber/coroutine stacks). Sequence: 1) Save current SP to old_stack_ptr, 2) Load new SP from new_stack_ptr, 3) MOV SP, X<new_sp>. Instructions: MOV X<tmp>, SP / LDR X<new>, [addr] / MOV SP, X<new>. Critical for fiber/coroutine support. Note: May require special register allocation handling for SP.
