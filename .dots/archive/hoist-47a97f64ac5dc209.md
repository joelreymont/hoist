---
title: Implement MSUB fusion pattern
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:32.613223+02:00"
closed-at: "2026-01-06T19:01:03.507879+02:00"
---

File: src/codegen/lower_aarch64.zig. Add pattern matching to fuse isub(x, imul(y, z)) → MSUB instruction. Detect pattern in IR during lowering. Emit single MSUB instead of MUL+SUB sequence. Expected 5-10% performance improvement. Reference: Cranelift lower.isle msub patterns. Part of Phase 2 optimization. Estimate: 1 day.
