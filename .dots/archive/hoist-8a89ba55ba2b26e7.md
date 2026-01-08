---
title: Implement basic spill/reload emission
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T21:06:37.704147+02:00\""
closed-at: "2026-01-08T21:07:02.111434+02:00"
---

File: src/codegen/compile.zig. Replace all @panic("Spilling not yet implemented") with actual spill/reload code. For spills: allocate stack space, emit STR to save vreg to stack slot. For reloads: emit LDR to load from stack slot. Calculate slot offset: slot_index * 8 + stack_frame_size. Prerequisite for STP coalescing. ~45 min.
