---
title: "P2.5.16: vconst infrastructure blocked"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T14:05:11.278680+02:00"
closed-at: "2026-01-05T16:38:40.463224+02:00"
---

File: src/backends/aarch64/lower.isle - vconst pattern requires: (1) vconst IR opcode (not implemented), (2) LowerCtx.getConstantData() API (not implemented), (3) u128_from_constant extractor, (4) constant_f128 constructor. Should be implemented after IR opcode support is added. Cranelift:2303-2304.
