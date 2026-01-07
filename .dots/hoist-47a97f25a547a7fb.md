---
title: Implement bit manipulation (CLZ/RBIT/POPCNT)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:28.482644+02:00"
closed-at: "2026-01-05T23:34:06.454030+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower clz IR opcode to CLZ. Lower ctz to RBIT+CLZ. Lower popcnt to CNT (vector register path). Handle 32-bit and 64-bit variants. Reference: Cranelift lower.isle bit manipulation patterns. Part of Phase 2 core functionality. Estimate: 1 day.
