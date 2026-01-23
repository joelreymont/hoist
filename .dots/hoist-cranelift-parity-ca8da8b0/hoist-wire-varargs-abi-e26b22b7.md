---
title: Wire varargs abi
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.530506+02:00\""
closed-at: "2026-01-23T14:29:54.127508+02:00"
---

Files: src/backends/aarch64/abi.zig:329-362
Root cause: va_list helpers exist but are not wired into prologue/ABI.
Fix: add varargs save-area emission for variadic callees.
Why: correct va_start/va_arg semantics.
Deps: Add varargs flag.
Verify: varargs ABI tests.
