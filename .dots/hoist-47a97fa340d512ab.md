---
title: Implement complex shuffle patterns
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:36.714463+02:00"
closed-at: "2026-01-06T22:15:21.251337+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower arbitrary shuffles using TBL/TBX instructions. Implement all 50+ shuffle patterns from Cranelift (swizzle, concat, interleave, etc.). Optimize for common patterns. Reference: Cranelift lower.isle complete shuffle coverage. Part of Phase 3 SIMD. High complexity. Estimate: 3 days.
