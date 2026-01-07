---
title: Add LD1R instruction struct to inst.zig
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T22:28:07.250926+02:00\""
closed-at: "2026-01-07T23:39:27.381632+02:00"
---

File: src/backends/aarch64/inst.zig ~line 1400 - Add LD1R instruction struct. Fields: dst:WritableReg, base:Reg, offset:i32 (optional post-index), size:VecElemSize. Supports all NEON element sizes. Part of NEON load/store instructions. Depends on hoist-ef3fea5ecd641c58.
