---
title: Implement urem_imm lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T09:10:24.074221+02:00"
closed-at: "2026-01-06T09:13:31.913646+02:00"
---

Implement unsigned remainder by immediate in src/codegen/compile.zig:lowerInstructionAArch64. For power-of-2, use AND with (imm-1). For general case: MOVZ imm, UDIV quot, MSUB result=dividend-quot*divisor.
