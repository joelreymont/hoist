---
title: Fix isle memory
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.303047+02:00"
---

Files: tests/isle_memory.zig, build.zig:283-293. Cause: API drift. Fix: update memory flags + InstructionData usage and re-enable. Why: ISLE memory coverage. Verify: zig build test.
