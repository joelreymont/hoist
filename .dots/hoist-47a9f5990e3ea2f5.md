---
title: Implement integer argument classification
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:35.757640+02:00"
closed-at: "2026-01-06T11:01:48.095019+02:00"
---

File: src/backends/aarch64/abi.zig. Classify integer arguments: first 8 in X0-X7, rest on stack (16-byte aligned). Handle i8/i16/i32 (zero/sign extended to 64-bit in register), i64 (direct), i128 (2 registers or stack if >8 args). Dependencies: type system. Effort: 1-2 days.
