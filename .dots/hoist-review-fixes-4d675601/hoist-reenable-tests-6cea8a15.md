---
title: Reenable tests
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-17T12:46:36.984502+02:00\""
closed-at: "2026-01-17T12:48:39.453942+02:00"
close-reason: split into per-test dots
---

Files: build.zig:100-379, tests/*.zig. Cause: many tests commented due to API drift. Fix: update tests to current APIs and re-enable in build.zig. Why: restore integration coverage. Verify: zig build test.
