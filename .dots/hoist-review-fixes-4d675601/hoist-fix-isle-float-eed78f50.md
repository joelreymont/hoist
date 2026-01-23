---
title: Fix isle float
status: closed
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.325824+02:00"
closed-at: "2026-01-23T21:11:30.000000+00:00"
---

Files: tests/isle_float.zig, build.zig:319-329. Cause: API drift. Fix: update InstructionData usage and re-enable. Why: ISLE float coverage. Verify: zig build test.
