---
title: Add ARM64 fcvt_from_sint/uint and fpromote/fdemote
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T14:54:26.458070+02:00"
closed-at: "2026-01-03T15:36:15.116322+02:00"
---

File: src/backends/aarch64/lower.isle - Add lowering: fcvt_from_sint→SCVTF (scalar/vector), fcvt_from_uint→UCVTF, fpromote(f32→f64)→FCVT, fdemote(f64→f32)→FCVT - Accept: All float conversions lower to ARM64 - Depends: 'Add type conversion InstructionData variants'
