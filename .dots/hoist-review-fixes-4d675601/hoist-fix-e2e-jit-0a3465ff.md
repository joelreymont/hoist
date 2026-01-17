---
title: Fix e2e jit
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.229920+02:00"
---

Files: tests/e2e_jit.zig, build.zig:126-137. Cause: API drift (AbiParam, firstResult, context). Fix: update APIs and re-enable. Why: JIT integration coverage. Verify: zig build test.
