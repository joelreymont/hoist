---
title: Implement stack slot allocation strategy
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:37.645377+02:00"
closed-at: "2026-01-06T11:05:35.584669+02:00"
---

File: src/codegen/stack_frame_aarch64.zig. Allocate slots for: (1) spills (from regalloc), (2) local variables, (3) outgoing call arguments (if >8 args). 16-byte alignment required. Slot reuse for non-overlapping lifetimes. Calculate total frame size. Dependencies: liveness analysis. Effort: 2 days.
