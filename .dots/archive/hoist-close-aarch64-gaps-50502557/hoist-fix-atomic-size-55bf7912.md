---
title: Fix atomic size
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T14:45:33.039384+02:00\""
closed-at: "2026-01-14T14:49:27.843675+02:00"
close-reason: use LSE size bits
---

File: src/backends/aarch64/emit.zig:2980. Root cause: emitAtomicOp uses sf bit (1-bit) instead of 2-bit size field, clearing bit31 for 32-bit ops. Fix: compute size bits (size32=0b10, size64=0b11) and shift into bits 31-30; restrict sizes. Verify: zig build test --cache-dir /tmp/hoist-zig-cache --global-cache-dir /tmp/hoist-zig-global.
