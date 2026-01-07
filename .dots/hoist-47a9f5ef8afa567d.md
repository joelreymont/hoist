---
title: Implement register class separation
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:41.425671+02:00"
closed-at: "2026-01-06T23:04:49.780218+02:00"
---

File: src/regalloc/register_classes.zig. Separate allocators for register classes: (1) integer general-purpose (X0-X30, exclude SP/XZR/X18), (2) FP/SIMD (V0-V31). Handle ABI-reserved registers: X0-X7 for args, X19-X28 callee-save, X8 struct return. Dependencies: none. Effort: 1 day.
