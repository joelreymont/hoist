---
title: Implement return_call tail call optimization
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:27:56.263380+02:00"
closed-at: "2026-01-06T21:04:17.697346+02:00"
---

File: src/codegen/compile.zig - Add lowering for return_call. Pop frame, restore callee-saves, then BR (not BL) to target. Reuses caller's return address. P0 critical for tail recursion.
