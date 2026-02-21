---
title: add compiler pgo tuning workflow
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-22T08:37:47.599141+01:00\\\"\""
closed-at: "2026-02-22T08:49:55.851222+01:00"
close-reason: completed
---

Context: Zig 0.15 lacks native -fprofile-generate/-fprofile-use; add compiler-level PGO workflow by exposing optimization thresholds (alias/range/egraph/fold-iadd) via Context/Target env overrides and adding a pgo tuner tool that runs benchmark training/gating and selects best no-regression config toward 2x budget. Verify: zig build test -j1; run tool smoke; benchmark compare with chosen config.
