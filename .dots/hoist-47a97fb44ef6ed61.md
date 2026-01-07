---
title: Implement vector widen/narrow
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:37.832194+02:00"
closed-at: "2026-01-06T21:34:51.143281+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower vector widen (8→16, 16→32, 32→64) to SXTL/UXTL instructions. Lower vector narrow (16→8, 32→16, 64→32) to XTN instruction. Support signed/unsigned variants. Reference: Cranelift lower.isle widen/narrow patterns. Part of Phase 3 advanced SIMD. Estimate: 1 day.
