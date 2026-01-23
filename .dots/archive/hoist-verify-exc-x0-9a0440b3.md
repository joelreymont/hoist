---
title: Verify exception X0 semantics
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:06:45.604024+02:00\""
closed-at: "2026-01-26T10:01:55.997056+01:00"
---

Files: src/backends/aarch64/abi.zig:28-149
What: Verify exception pointer ABI matches Cranelift
Question: X0 null vs exception pointer semantics?
Method: Compare try_call behavior with Cranelift
Verification: Exception handling matches Cranelift
