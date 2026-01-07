---
title: Add argument classification tests
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:02:17.103626+02:00"
closed-at: "2026-01-07T07:34:36.554616+02:00"
---

File: tests/abi_args.zig - Test: 0 args (nothing), 4 args (all in regs X0-X3), 10 args (first 8 in regs, last 2 on stack), i128 arg (register pair), mixed i8/i16/i32/i64 (verify extension). Check ArgLocation correctness. Dependencies: hoist-47b46e4996a52dcf.
