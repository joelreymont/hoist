---
title: Fix atomic sigs
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-02T23:54:59.754292+01:00\\\"\""
closed-at: "2026-02-03T12:00:56.671287+01:00"
close-reason: Normalize atomic_load/store patterns
blocks:
  - hoist-fix-a64-sigs-cd143b98
---

File: src/backends/aarch64/lower.isle:4300-4500; cause: atomic_load/store signatures inconsistent (2/3 vs 4 args); fix: normalize to declared IR signature and update patterns; why: avoid ISLE type errors.
