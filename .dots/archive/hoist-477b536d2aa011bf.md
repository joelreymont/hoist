---
title: Add ARM64 SIMD narrowing ISLE rules
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T14:54:26.476714+02:00"
closed-at: "2026-01-03T16:18:00.377918+02:00"
---

File: src/backends/aarch64/lower.isle - Add lowering: snarrow→SQXTN+SQXTN2, unarrow→SQXTUN+SQXTUN2, uunarrow→UQXTN+UQXTN2 - Implement saturation (clamp to i16::MAX=32767, i16::MIN=-32768) - Accept: Narrowing ops lower with saturation - Depends: 'Add SIMD vector InstructionData variants'
