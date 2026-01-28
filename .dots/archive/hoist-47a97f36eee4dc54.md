---
title: Implement FP rounding (FRINT variants)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:29.615598+02:00"
closed-at: "2026-01-05T23:21:29.245205+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower ceil/floor/trunc/nearest IR opcodes to FRINTP/FRINTM/FRINTZ/FRINTN instructions. Support f32 and f64. Reference: Cranelift lower.isle FP rounding patterns. Part of Phase 2 core functionality. Estimate: 0.5 days.
