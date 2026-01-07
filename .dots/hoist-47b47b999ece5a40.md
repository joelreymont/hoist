---
title: Implement slot reuse optimization
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:05:53.614553+02:00"
closed-at: "2026-01-07T06:30:51.075886+02:00"
---

File: src/codegen/stack_slots.zig - Enhance StackSlotAllocator with liveness-based reuse. Track free_slots per size. When vreg dies, mark slot as reusable. allocSlot: check free_slots first before advancing next_offset. Reduces frame size. Dependencies: hoist-47b47b175c5a006e, hoist-47b4651ff65bb528.
