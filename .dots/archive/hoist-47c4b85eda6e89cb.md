---
title: Add stack probe for large frames
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:28:12.650109+02:00"
closed-at: "2026-01-07T06:47:15.684588+02:00"
---

File: src/backends/aarch64/abi.zig - Implement stack probe loop for frames >4KB to avoid guard page miss. Required by some platforms for security. Algorithm: At function prologue, if frame_size > threshold, emit loop: SUB SP, #4096 / STR XZR, [SP] / repeat until full frame allocated. Prevents stack overflow attacks. Platform-specific requirement for Windows ARM64, optional for Unix.
