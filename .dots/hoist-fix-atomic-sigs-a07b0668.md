---
title: Fix atomic sigs
status: active
priority: 1
issue-type: task
created-at: "\"2026-02-02T23:54:59.754292+01:00\""
blocks:
  - hoist-fix-a64-sigs-cd143b98
---

File: src/backends/aarch64/lower.isle:4300-4500; cause: atomic_load/store signatures inconsistent (2/3 vs 4 args); fix: normalize to declared IR signature and update patterns; why: avoid ISLE type errors.
