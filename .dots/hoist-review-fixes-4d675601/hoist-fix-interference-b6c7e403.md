---
title: Fix interference
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.341167+02:00"
---

Files: tests/interference.zig, build.zig:368-379. Cause: liveness export path changes. Fix: update imports to current regalloc/liveness modules and re-enable. Why: regalloc coverage. Verify: zig build test.
