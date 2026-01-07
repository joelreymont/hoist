---
title: Lower stack_load, stack_store, stack_addr
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:10:15.315881+02:00"
closed-at: "2026-01-07T09:49:03.641827+02:00"
---

File: src/generated/aarch64_lower_generated.zig add new patterns
Opcodes: stack_load, stack_store, stack_addr
Need: Access stack slots via frame pointer
Implementation (~40 lines each):
- stack_load: Get stack slot, compute FP offset, emit ldr with offset
- stack_store: Same with str
- stack_addr: emit add from FP with stack slot offset
Dependencies: hoist-emit-002 (frame layout must be computed)
Estimated: 1 day
Test: Test stack slot access
