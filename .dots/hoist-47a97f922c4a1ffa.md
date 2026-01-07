---
title: Implement vector splat operations
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:35.595093+02:00"
closed-at: "2026-01-06T10:32:46.022668+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower vector splat IR opcode to DUP instruction (replicate scalar to all lanes). Support all lane sizes (8/16/32/64-bit). Reference: Cranelift lower.isle splat patterns. Part of Phase 3 SIMD. Estimate: 0.5 days.
