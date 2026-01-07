---
title: Implement dynamic stack allocation
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:34.625773+02:00"
closed-at: "2026-01-07T06:30:27.152681+02:00"
---

File: src/codegen/lower_aarch64.zig. Opcodes: dynamic_stack_load, dynamic_stack_store, dynamic_stack_addr. Support alloca-like behavior (runtime-sized stack allocation). Pattern: SUB SP, SP, size + alignment. Must update frame pointer if used. Dependencies: stack frame management, alignment. Effort: 1-2 days.
