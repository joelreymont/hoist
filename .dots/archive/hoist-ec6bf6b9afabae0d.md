---
title: Add ISLE lowering for f32const/f64const
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T13:00:18.502956+02:00\""
closed-at: "2026-01-08T13:22:35.247567+02:00"
---

File: src/backends/aarch64/lower.isle, isle_helpers.zig - Add lowering rules for f32const and f64const opcodes. For small constants: use FMOV immediate. For others: materialize in constant pool, use ADRP+LDR to load. Pattern: (lower (f32const k)) -> (aarch64_f32const k). Depends on: constant pool support. Enables: FP constant materialization.
