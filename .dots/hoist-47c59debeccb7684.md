---
title: Implement Fast calling convention register allocation
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:32:23.877851+02:00"
closed-at: "2026-01-07T08:03:48.519086+02:00"
---

File: src/backends/aarch64/abi.zig:~550 (computeArgsAndRets). Fast convention: maximize register args, minimize stack. Pass up to X0-X17 for int args (vs X0-X7 standard), V0-V15 for FP args (vs V0-V7 standard). No stack homing for register args. Caller responsible for preserving all volatiles. ~40 lines in computeArgsAndRets switch. Test: verify >8 int args use registers not stack. Depends: CallConv enum (hoist-47c59c479e51fe45).
