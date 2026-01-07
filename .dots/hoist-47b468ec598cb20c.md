---
title: Add linear scan tests
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:00:40.269208+02:00"
closed-at: "2026-01-06T22:43:07.488828+02:00"
---

File: tests/linear_scan.zig - Test: 2 non-overlapping vregs (share reg), 3 overlapping vregs (use 3 regs), register pressure (N vregs with N-1 regs available triggers spill). Compare output to trivial allocator. Verify correctness. Dependencies: hoist-47b46891acee09ac.
