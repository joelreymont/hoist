---
title: Wire stack slots to lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:06:43.310368+02:00"
closed-at: "2026-01-07T06:30:51.080949+02:00"
---

File: src/codegen/compile.zig - Create StackSlotAllocator early. During lowering, when lowering stack_addr/stack_load/stack_store, call allocator.getSlot(stack_slot_id) to get offset from FP. Use that offset in LDR/STR instructions. Dependencies: hoist-47b47b175c5a006e.
