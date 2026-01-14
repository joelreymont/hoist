---
title: Enable isle tests
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.822726+02:00"
---

Files: build.zig:258-329
Root cause: ISLE coverage tests are commented out.
Fix: fix API mismatches and re-enable isle_coverage/isle_compare/isle_* tests.
Why: ISLE rule coverage parity.
Deps: Wire x64 lower, fix ISLE APIs.
Verify: zig build test.
