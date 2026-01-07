---
title: Add ArgLocation enum
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:01:48.100570+02:00"
closed-at: "2026-01-06T22:43:07.441652+02:00"
---

File: src/backends/aarch64/abi.zig - Define ArgLocation enum: Register(PhysReg), Stack(offset: i32), RegisterPair(r1, r2). Used to describe where each argument lives per AAPCS64. Dependencies: none.
