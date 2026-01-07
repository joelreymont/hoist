---
title: Implement overflow with carry-in and traps
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:31.992244+02:00"
closed-at: "2026-01-06T20:20:24.340719+02:00"
---

File: src/codegen/lower_aarch64.zig. Opcodes: sadd_overflow_cin, uadd_overflow_cin, uadd_overflow_trap. Carry-in variants use ADCS. Trap variants combine overflow detection with conditional trap (B.VS + BRK). Dependencies: trap infrastructure. Effort: 1 day.
