---
title: Add tailcall restore
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.553771+02:00"
---

Files: src/backends/aarch64/isle_helpers.zig:3225-3233
Root cause: tail call path skips callee-save and FP/LR restore.
Fix: emit restore sequence using ABI metadata.
Why: correct tail calls and ABI conformance.
Deps: Add tailcall stack.
Verify: tail call tests.
