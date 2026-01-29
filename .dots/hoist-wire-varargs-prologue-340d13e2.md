---
title: Wire varargs prologue
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T23:31:37.037587+01:00"
---

Context: src/backends/aarch64/abi.zig:1370, 3446; cause: varargs save area exists but relies on sig.is_varargs; fix: ensure call/prologue paths invoke save area when is_varargs true and expose offset to va_start; deps: Wire varargs flag; verification: add unit test for varargs save area layout.
