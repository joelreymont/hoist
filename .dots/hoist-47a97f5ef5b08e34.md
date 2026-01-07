---
title: Implement MADD fusion pattern
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:32.238781+02:00"
closed-at: "2026-01-06T19:00:10.865450+02:00"
---

File: src/codegen/lower_aarch64.zig. Add pattern matching to fuse iadd(x, imul(y, z)) → MADD instruction. Detect pattern in IR during lowering. Emit single MADD instead of MUL+ADD sequence. Expected 5-10% performance improvement. Reference: Cranelift lower.isle madd patterns. Part of Phase 2 optimization. Estimate: 1 day.
