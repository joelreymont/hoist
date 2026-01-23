---
title: Add return tests
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.571669+02:00\""
closed-at: "2026-01-23T15:00:21.086871+02:00"
---

Files: src/backends/aarch64/isle_helpers.zig:3771-3880
Root cause: no tests for multi-return and sret paths.
Fix: add tests covering multi-return, FP return, sret and HFA.
Why: prevent ABI regressions.
Deps: Wire multi return.
Verify: zig build test.
