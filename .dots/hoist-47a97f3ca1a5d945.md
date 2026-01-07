---
title: Add FP parameter passing to ABI
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:29.989039+02:00"
closed-at: "2026-01-06T18:20:34.743013+02:00"
---

File: src/backends/aarch64/abi.zig. Extend ABI module to handle FP parameter passing in v0-v7 registers. Implement FP return value handling. Handle mixed int/FP parameter lists. Reference: AAPCS64 section 6.8.2. Depends on hoist-47a9749909153f16. Part of Phase 2 core functionality. Estimate: 1 day.
