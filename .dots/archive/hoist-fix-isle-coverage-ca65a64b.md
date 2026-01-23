---
title: Fix ISLE coverage tracking
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-23T21:50:17.881928+02:00\""
closed-at: "2026-01-23T21:55:17.468471+02:00"
---

File: src/backends/aarch64/isle_helpers.zig:58. Cause: recordRule() defined but never called from generated code. Fix: ISLE codegen needs to emit recordRule calls in constructor bodies. Why: Enable isle_compare.zig tests. Verify: coverage.uniqueRulesInvoked() > 0. Dep: ISLE compiler changes.
