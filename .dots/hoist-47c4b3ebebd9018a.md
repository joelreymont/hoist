---
title: Implement dynamic_stack_addr opcode
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:26:58.009061+02:00"
closed-at: "2026-01-07T06:52:08.774331+02:00"
---

File: src/backends/aarch64/lower.isle + isle_helpers.zig - Add lowering for dynamic_stack_addr (compute address in dynamically allocated stack space). Algorithm: 1) Read dynamic stack pointer (stored in callee-save register or frame slot), 2) ADD offset to get variable address, 3) Return address register. Need dynamic stack pointer tracking infrastructure. Instruction: ADD Xd, X<dyn_sp>, #offset. Dependencies: dynamic stack allocation infrastructure. Critical for alloca-style dynamic allocations.
