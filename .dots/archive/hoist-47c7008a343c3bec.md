---
title: Lower bitselect opcode
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:11:33.385287+02:00"
closed-at: "2026-01-07T10:05:20.085235+02:00"
---

File: src/generated/aarch64_lower_generated.zig add pattern
Opcode: bitselect (bitwise select: (a & c) | (b & ~c))
Implementation (~50 lines): Get operands a, b, c, emit bsl instruction (bit select) if available, or and + bic + orr sequence
Dependencies: None
Estimated: 4 hours
Test: Test bitselect
