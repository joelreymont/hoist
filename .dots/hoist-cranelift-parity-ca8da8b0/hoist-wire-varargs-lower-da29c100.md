---
title: Wire varargs lower
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.536407+02:00\""
closed-at: "2026-01-23T14:32:43.003732+02:00"
---

Files: src/backends/aarch64/isle_helpers.zig:3453-3520
Root cause: call lowering does not consider variadic signatures.
Fix: plumb is_varargs into call lowering and va_start lowering.
Why: variadic callsite correctness.
Deps: Add varargs flag, Wire varargs abi.
Verify: varargs lowering tests.
