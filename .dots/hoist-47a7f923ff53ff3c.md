---
title: "P0.6: Verify w0 register preservation"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T20:10:25.260384+02:00"
closed-at: "2026-01-05T20:28:02.320864+02:00"
close-reason: Verified via ABI test - w0 is correctly preserved and read as return value
---

File: tests/e2e_jit.zig - Add test that clobbers other regs (w1) but returns value in w0. Ensures we're reading the right register. Generate: movz w0, #42; movz w1, #99; ret - should return 42 not 99.
