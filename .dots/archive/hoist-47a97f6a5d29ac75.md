---
title: Implement shifted operand fusion
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:32.986163+02:00"
closed-at: "2026-01-06T19:14:15.580590+02:00"
---

File: src/codegen/lower_aarch64.zig. Add pattern matching to fuse iadd(x, shl(y, const)) → ADD with LSL shift modifier. Detect shift patterns in IR. Use shifted register encoding. Expected 10-15% performance improvement. Reference: Cranelift lower.isle shift patterns. Part of Phase 2 optimization. Estimate: 1 day.
