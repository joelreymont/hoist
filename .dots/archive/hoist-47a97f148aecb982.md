---
title: Implement remainder (SDIV + MSUB)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:27.361786+02:00"
closed-at: "2026-01-05T23:19:39.063930+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower srem/urem IR opcodes using SDIV/UDIV + MSUB pattern (rem = dividend - divisor * quotient). Handle 32-bit and 64-bit variants. Reference: Cranelift lower.isle remainder patterns. Part of Phase 2 core functionality. Estimate: 0.5 days.
