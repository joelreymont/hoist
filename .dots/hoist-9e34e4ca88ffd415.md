---
title: Complete try_call branch emission
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T06:08:14.427241+02:00"
---

File: src/generated/aarch64_lower_generated.zig:2656. After BL emission, add CBZ X0, normal_successor and B exception_successor. Requires block label management in emission. May need to emit branches as part of block terminator handling rather than inline in try_call lowering. Consider handling try_call as terminator instruction.
