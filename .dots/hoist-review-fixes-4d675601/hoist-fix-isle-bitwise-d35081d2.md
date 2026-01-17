---
title: Fix isle bitwise
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.310743+02:00"
---

Files: tests/isle_bitwise.zig, build.zig:295-305. Cause: API drift. Fix: update InstructionData usage and re-enable. Why: ISLE bitwise coverage. Verify: zig build test.
