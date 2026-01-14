---
title: Add interp mem
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.851838+02:00"
---

Files: src/interpreter/interpreter.zig (new)
Root cause: interpreter lacks memory model.
Fix: add stack slot and heap memory model for load/store/stack_load.
Why: correct execution semantics.
Deps: Add ir interp.
Verify: interpreter memory tests.
