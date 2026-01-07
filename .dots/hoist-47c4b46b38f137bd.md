---
title: Implement dynamic_stack_load opcode
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:27:06.351876+02:00"
closed-at: "2026-01-07T06:54:10.784576+02:00"
---

File: src/backends/aarch64/lower.isle - Add lowering for dynamic_stack_load (load from dynamically allocated stack). Pattern: LDR Xd, [X<dyn_sp>, #offset]. Compute effective address (dynamic_sp + offset), emit load instruction. Similar to normal stack_load but uses dynamic stack pointer instead of frame pointer. Dependencies: dynamic stack pointer tracking. Instruction: LDR with dynamic base register.
