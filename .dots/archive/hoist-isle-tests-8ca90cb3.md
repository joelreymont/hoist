---
title: ISLE tests
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T20:16:24.404656+01:00\""
closed-at: "2026-01-29T20:44:14.211548+01:00"
close-reason: completed
---

Full context: src/dsl/isle/parser.zig tests don't cover real syntax. Cause: minimal tests. Fix: add parser/sema tests for lower.isle constructs and const/bind/let. Why: prevent regressions.
