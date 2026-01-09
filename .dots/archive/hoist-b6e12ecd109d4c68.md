---
title: Implement PreserveMost calling convention
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T07:45:41.878316+02:00\""
closed-at: "2026-01-09T08:20:28.097367+02:00"
---

Implement PreserveMost ABI (preserves most registers, minimal caller-save). Used for runtime stubs. Add classifyArgsPreserveMost() in src/backends/aarch64/abi.zig. Files: src/backends/aarch64/abi.zig:450+ (new). ~60 min.
