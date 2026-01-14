---
title: Add varargs flag
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.524375+02:00"
---

Files: src/ir/signature.zig:119-136
Root cause: Signature lacks varargs flag.
Fix: add is_varargs field and helpers; thread through signature creation.
Why: enable variadic call ABI handling.
Deps: none.
Verify: signature tests.
