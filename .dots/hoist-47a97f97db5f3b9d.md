---
title: Implement lane extract/insert
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:35.967593+02:00"
closed-at: "2026-01-06T10:32:58.420936+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower extractlane/insertlane IR opcodes to UMOV/INS instructions. Support all lane sizes and indices. Reference: Cranelift lower.isle lane patterns. Part of Phase 3 SIMD. Estimate: 1 day.
