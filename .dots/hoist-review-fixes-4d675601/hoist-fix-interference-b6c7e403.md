---
title: Fix interference
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-17T12:48:35.341167+02:00\""
closed-at: "2026-01-23T22:57:10.639699+02:00"
---

Files: tests/interference.zig, build.zig:368-379. Cause: liveness export path changes. Fix: update imports to current regalloc/liveness modules and re-enable. Why: regalloc coverage. Verify: zig build test.
