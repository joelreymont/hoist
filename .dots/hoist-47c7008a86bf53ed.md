---
title: Lower sqrt, ceil, floor, trunc, nearest
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:11:33.406409+02:00"
closed-at: "2026-01-07T10:18:03.151443+02:00"
---

File: src/generated/aarch64_lower_generated.zig add patterns
Opcodes: sqrt, ceil, floor, trunc, nearest
Implementation (~25 lines each): sqrt - fsqrt instruction, ceil - frintp (round toward positive infinity), floor - frintm (round toward negative infinity), trunc - frintz (round toward zero), nearest - frintn (round to nearest, ties to even)
Dependencies: None
Estimated: 1 day
Test: Test each operation
