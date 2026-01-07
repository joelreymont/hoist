---
title: Implement LD1R encoding in emit.zig
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T22:28:14.694242+02:00\""
closed-at: "2026-01-07T23:42:13.109592+02:00"
---

File: src/backends/aarch64/emit.zig - Add emitLd1r function. Encoding: Advanced SIMD load/store single structure, opcode 0b1101 (LD1R), Q bit for 128-bit, size in bits 10-11. See ARM ARM C7.2.175. Handle all vector sizes and post-indexed addressing. Depends on hoist-e3bb426ca99174cf.
