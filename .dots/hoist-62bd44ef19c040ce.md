---
title: Implement tail call frame deallocation
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T12:45:34.930271+02:00"
---

File: src/backends/aarch64/isle_impl.zig - Before tail jump, deallocate current frame: restore FP, restore LR if needed, adjust SP to caller. Emit: ADD SP, FP, #0; LDP FP, LR, [SP], #16. Depends on: none. Enables: stack cleanup before tail jump.
