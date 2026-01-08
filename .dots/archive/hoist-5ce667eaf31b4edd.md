---
title: Implement return_call frame deallocation
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T22:29:36.693454+02:00\""
closed-at: "2026-01-08T12:45:42.237627+02:00"
---

File: src/backends/aarch64/isle_impl.zig:1903 - Deallocate current stack frame before tail jump. Restore callee-save registers. Restore FP and SP to caller's frame. Do NOT restore LR (we're jumping, not returning). After this, stack looks like we never called current function. Part of hoist-47cc3973f3c9bd63.
