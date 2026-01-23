---
title: Fix isle compare
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-17T12:48:35.295265+02:00\""
closed-at: "2026-01-23T21:50:21.534716+02:00"
---

Files: tests/isle_compare.zig, build.zig:271-281. Cause: API drift. Fix: update InstructionData/DFG usage and re-enable. Why: ISLE compare coverage. Verify: zig build test.
