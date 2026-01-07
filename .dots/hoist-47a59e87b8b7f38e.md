---
title: Debug E2E test runtime panics
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T17:21:55.134662+02:00"
closed-at: "2026-01-05T17:29:40.513262+02:00"
---

E2E tests (e2e_jit, e2e_branches, e2e_loops) compile successfully but hit runtime panics during execution. Errors: 'index out of bounds: index 0, len 0' and 'reached unreachable code'. Need to debug execution to identify root cause. All 397 unit tests pass.
