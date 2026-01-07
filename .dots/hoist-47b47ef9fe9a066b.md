---
title: Add stack allocation tests
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:06:50.262179+02:00"
closed-at: "2026-01-07T06:30:51.085564+02:00"
---

File: tests/stack_allocation.zig - Test: small frame <512 bytes (no probe), large frame 8KB (needs probe), huge frame 512KB (multiple immediates), slot reuse (3 vregs, 2 non-overlapping share slot), alignment (i64 requires 8-byte). Dependencies: hoist-47b47d14bf4b319c, hoist-47b47d9baa226f9f, hoist-47b47e0d725a27fd, hoist-47b47e8feb16ec1d.
