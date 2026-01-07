---
title: Implement division (sdiv/udiv)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:26.984764+02:00"
closed-at: "2026-01-05T23:00:02.842655+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower sdiv/udiv IR opcodes to SDIV/UDIV instructions. Handle 32-bit and 64-bit variants. Reference: Cranelift lower.isle division patterns. Part of Phase 2 core functionality. Estimate: 0.5 days.
