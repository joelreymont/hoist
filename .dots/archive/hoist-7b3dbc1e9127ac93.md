---
title: Implement return value marshaling codegen
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T11:46:25.630129+02:00\""
closed-at: "2026-01-08T15:08:31.039051+02:00"
---

File: src/backends/aarch64/isle_helpers.zig or abi.zig. Generate instructions to move values to return registers. Handle loading struct fields to registers (HFA). Handle copying to return buffer (indirect). Dependencies: sret support. Effort: <30min
