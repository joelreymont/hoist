---
title: Create spill slot to stack slot mapping
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T11:46:25.542077+02:00\""
closed-at: "2026-01-08T12:12:42.990333+02:00"
---

File: src/regalloc/slot_mapping.zig (new). Registry mapping abstract SpillSlot offset → IR StackSlot entity. Function to allocate new IR StackSlot for each regalloc spill. Add unit test for mapping + lookup. Dependencies: none. Effort: <30min
