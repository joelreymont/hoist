---
title: Wire egraph ir
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.776266+02:00\""
closed-at: "2026-01-23T23:57:03.316916+02:00"
---

Files: src/codegen/compile.zig:722-726
Root cause: optimize pipeline ignores extracted egraph results.
Fix: apply extracted IR and re-run verification.
Why: ensure egraph results are used.
Deps: Add egraph extract.
Verify: optimize pipeline tests.
