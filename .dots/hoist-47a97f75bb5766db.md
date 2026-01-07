---
title: Implement compare+branch fusion
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:33.731169+02:00"
closed-at: "2026-01-06T19:25:54.912339+02:00"
---

File: src/codegen/lower_aarch64.zig. Enhance brif lowering to detect compare+branch patterns and emit fused CMP+B.cond or CBZ/CBNZ. Avoid materializing comparison result in register when possible. Expected 10-15% performance improvement. Reference: Cranelift lower.isle branch patterns. Part of Phase 2 optimization. Estimate: 1 day.
