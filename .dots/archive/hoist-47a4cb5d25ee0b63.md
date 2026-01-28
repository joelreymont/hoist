---
title: Implement trivial iconst lowering for AArch64
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T16:22:52.351991+02:00"
closed-at: "2026-01-05T16:24:17.078438+02:00"
---

File: src/codegen/compile.zig:383-390 - Currently all IR instructions lower to NOP. Implement actual lowering for iconst (load immediate) as proof-of-concept. This will: (1) Show complete lowering flow, (2) Make one E2E test potentially passable, (3) Demonstrate VCodeBuilder usage. Steps: Read IR inst data, match iconst opcode, emit AArch64 mov immediate instruction. Target: Lower iconst i32 to movz instruction.
