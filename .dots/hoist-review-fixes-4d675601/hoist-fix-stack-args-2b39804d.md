---
title: Fix stack args
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.266773+02:00"
---

Files: tests/aarch64_stack_args.zig, build.zig:217-229. Cause: old InstructionData format. Fix: update to current InstructionData and builder; re-enable. Why: stack arg coverage. Verify: zig build test.
