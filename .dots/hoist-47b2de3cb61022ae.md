---
title: Implement sdiv_imm lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T09:10:18.535449+02:00"
closed-at: "2026-01-06T09:15:07.010460+02:00"
---

Implement signed division by immediate in src/codegen/compile.zig:lowerInstructionAArch64. For power-of-2, use ASR+corrections for negative dividends. For general case, load immediate and use SDIV.
