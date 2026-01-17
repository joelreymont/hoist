---
title: Fix isle coverage
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.288453+02:00"
---

Files: tests/isle_coverage.zig, build.zig:258-269. Cause: API change (firstResult->appendInstResult). Fix: update tests and re-enable. Why: ISLE coverage. Verify: zig build test.
