---
title: Implement bitwise ops (AND/ORR/EOR)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:28.109785+02:00"
closed-at: "2026-01-05T23:34:06.450793+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower band/bor/bxor IR opcodes to AND/ORR/EOR instructions. Handle immediate and register operands. Support logical immediate encoding for constants. Reference: Cranelift lower.isle bitwise patterns. Part of Phase 2 core functionality. Estimate: 1 day.
