---
title: Validate via test suite
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-17T10:38:33.816869+01:00\""
closed-at: "2026-02-17T10:38:33.843111+01:00"
close-reason: completed in jj commit 52a99349 with passing test, integration, jit, fuzz
---

Evidence: zig build test/test-integration/test-jit/fuzz all pass after fix. Why: prove no regressions and close root-cause chain.
