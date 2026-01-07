---
title: Implement srem_imm lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T09:10:28.744337+02:00"
closed-at: "2026-01-06T09:16:07.254842+02:00"
---

Implement signed remainder by immediate in src/codegen/compile.zig:lowerInstructionAArch64. Use MOVZ imm, SDIV quot, MSUB result=dividend-quot*divisor. Cannot optimize power-of-2 due to signed remainder semantics.
