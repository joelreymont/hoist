---
title: Implement return_call_indirect indirect tail call
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:28:00.407552+02:00"
closed-at: "2026-01-06T21:04:22.165149+02:00"
---

File: src/codegen/compile.zig - Add lowering for return_call_indirect. Pop frame, restore callee-saves, then BR (register) to target. P0 critical.
