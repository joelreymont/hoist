---
title: Fix isle conv
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.318280+02:00"
---

Files: tests/isle_conversions.zig, build.zig:307-317. Cause: API drift. Fix: update InstructionData usage and re-enable. Why: ISLE conversion coverage. Verify: zig build test.
