---
title: Implement move coalescing in register allocator
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:27:48.596821+02:00"
closed-at: "2026-01-07T06:43:01.809563+02:00"
---

File: src/regalloc/linear_scan.zig - Add move coalescing optimization to eliminate redundant register-to-register moves. Algorithm: 1) Identify MOV vreg1, vreg2 candidates, 2) Check safety: ranges don't interfere with each other's neighbors, same register class, 3) Merge live ranges, assign same physical register, 4) Mark MOV for deletion. Track coalesced moves in ArrayList. Reduces register pressure and code size. Optimization, not critical for correctness.
