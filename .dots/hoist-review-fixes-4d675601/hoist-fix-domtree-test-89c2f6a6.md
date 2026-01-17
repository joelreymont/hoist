---
title: Fix domtree test
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.333714+02:00"
---

Files: tests/domtree.zig, build.zig:355-366. Cause: cfg export path changes. Fix: update imports to hoist.cfg/hoist.ir.cfg and re-enable. Why: domtree coverage. Verify: zig build test.
