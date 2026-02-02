---
title: Tailcall stress tests
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.981686+01:00"
blocks:
  - hoist-status-e45ed634
---

tests/e2e_tail_calls.zig:266; cause: only baseline tailcall scenarios; fix: add high-arity, large stack arg, and mixed direct/indirect stress cases plus assertions; why: prevent ABI regressions.
