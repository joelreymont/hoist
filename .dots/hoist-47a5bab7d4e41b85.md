---
title: Fix Context/Function ownership for E2E JIT tests
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T17:29:48.049645+02:00"
closed-at: "2026-01-05T17:38:31.515250+02:00"
---

E2E JIT tests hit double-free error because codegen Context and user Function have ownership conflicts. Need to refactor compile() to either: (1) take Function pointer instead of copy, or (2) thread Function parameter through all internal functions instead of using ctx.func. This is blocking actual JIT execution tests from running.
