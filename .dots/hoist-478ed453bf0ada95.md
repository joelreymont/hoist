---
title: "P2.9.2: Add base float/vector load patterns"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T14:10:33.450263+02:00"
closed-at: "2026-01-04T14:11:22.569169+02:00"
---

File: src/backends/aarch64/lower.isle - Add 6 float/vector load patterns for F16/F32/F64/F128/V64/V128 types. Pattern: (load flags address offset) => aarch64_fpuload*. Cranelift:2656-2676.
