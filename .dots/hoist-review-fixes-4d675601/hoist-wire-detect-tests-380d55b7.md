---
title: Wire detect tests
status: open
priority: 2
issue-type: task
created-at: "2026-01-17T12:48:35.363583+02:00"
---

Files: src/target/features.zig tests. Cause: detection untested. Fix: add tests for feature parsing + detect() non-empty on native; gate by arch/OS. Why: ensure detection works. Verify: zig build test.
