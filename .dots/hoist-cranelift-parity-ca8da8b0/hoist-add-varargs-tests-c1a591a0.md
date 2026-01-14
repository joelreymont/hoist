---
title: Add varargs tests
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.542023+02:00"
---

Files: src/backends/aarch64/abi.zig:2762-2831
Root cause: tests only cover va_list structs, not lowering.
Fix: add callsite/prologue tests for variadic functions.
Why: ensure ABI correctness.
Deps: Wire varargs lower.
Verify: zig build test.
