---
title: Remove Panics and Error Masking
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.525412+01:00\""
closed-at: "2026-02-01T20:45:27.780615+01:00"
close-reason: "completed: all child panic/error-masking dots closed"
---

Context: src/module/data.zig:10; cause: panics/unreachable in core paths; fix: return errors and propagate; deps: hoist-plan-review-fixes-af4c6e65; verification: zig build test
