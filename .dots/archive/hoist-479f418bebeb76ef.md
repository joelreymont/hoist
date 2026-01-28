---
title: Port debug tags for IR annotation
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T09:46:25.325073+02:00"
closed-at: "2026-01-05T10:09:47.243334+02:00"
---

File: Create src/ir/debug_tags.zig from cranelift/codegen/src/ir/debug_tags.rs:1-120. Debug tags attach source location metadata to IR instructions. Used by debuggers and profilers. Root cause: source location tracking missing. Fix: Port DebugTag types, add to InstructionData or separate map.
