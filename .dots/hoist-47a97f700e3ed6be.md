---
title: Implement extended operand fusion
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:33.359175+02:00"
closed-at: "2026-01-06T19:21:58.974321+02:00"
---

File: src/codegen/lower_aarch64.zig. Add pattern matching to fuse iadd(x, sext(y)) → ADD with SXTW extend modifier. Detect extend patterns in IR. Use extended register encoding. Expected 5-10% performance improvement. Reference: Cranelift lower.isle extend patterns. Part of Phase 2 optimization. Estimate: 1 day.
