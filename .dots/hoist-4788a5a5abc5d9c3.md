---
title: "Dot 1.1: Implement trap opcode"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T06:48:00.486359+02:00"
closed-at: "2026-01-04T06:53:52.756561+02:00"
---

Files: lower.isle:1800 rule, isle_helpers.zig:1750 aarch64_trap fn. Rule: (rule (lower (trap trap_code)) (aarch64_trap trap_code)). Helper: return Inst{.udf={.imm=trap_code.toU16()}}. Test: UDF emission. 25min. Depends: Stage 0
