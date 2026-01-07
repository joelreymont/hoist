---
title: Implement tail call optimization
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:38.582201+02:00"
closed-at: "2026-01-06T20:25:17.871013+02:00"
---

File: src/codegen/lower_aarch64.zig and src/backends/aarch64/abi.zig. Detect tail calls (call as last instruction before return). Emit direct branch instead of call+return. Handle ABI constraints (matching signatures, no stack growth). Reference: Cranelift lower.isle tail call patterns. Part of Phase 2/3 optimization. Estimate: 2 days.
