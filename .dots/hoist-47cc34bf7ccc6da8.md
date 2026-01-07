---
title: Audit and implement getStackSlotOffset()
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T15:24:04.128989+02:00"
closed-at: "2026-01-07T15:33:57.280650+02:00"
---

BLOCKER - Must be done first. Grep for getStackSlotOffset calls in LowerCtx. Function is called in isle_helpers.zig:2467 but is undefined. Implement in LowerCtx to map stack slots to frame offsets. Account for FP/LR, callee-saves, and 16-byte alignment. Test: Query offset for various stack slots. Phase 1.0, Priority P0
