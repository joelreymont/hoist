---
title: Add tailcall stack
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.548026+02:00"
---

Files: src/backends/aarch64/isle_helpers.zig:3217-3223
Root cause: tail calls reject stack arguments.
Fix: implement stack arg copying with overlap-safe layout before frame pop.
Why: tail call correctness with stack args.
Deps: none.
Verify: tail call tests.
