---
title: Implement mul overflow detection
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:31.616524+02:00"
closed-at: "2026-01-06T08:25:37.119707+02:00"
---

File: src/codegen/lower_aarch64.zig. Opcodes: smul_overflow, umul_overflow. Instructions: MUL (low bits) + SMULH/UMULH (high bits) + CMP (check if high bits indicate overflow). More complex than add/sub. Dependencies: multi-value returns. Effort: 1-2 days.
