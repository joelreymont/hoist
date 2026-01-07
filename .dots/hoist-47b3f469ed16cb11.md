---
title: Implement dynamic_stack_addr dynamic stack allocation address
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:28:05.564706+02:00"
closed-at: "2026-01-07T06:30:27.162720+02:00"
---

File: src/codegen/compile.zig - Add lowering for dynamic_stack_addr. Compute address on dynamically allocated stack space (alloca-style). Requires tracking dynamic stack pointer. P0 for dynamic allocations.
