---
title: Lower spectre_fence to AArch64 ISB
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T08:18:01.951326+02:00\""
closed-at: "2026-01-09T08:26:09.988666+02:00"
---

Lower spectre_fence to AArch64 ISB (Instruction Synchronization Barrier) in src/backends/aarch64/lower.isle. Add ISB instruction variant to inst.zig. Add emission in emit.zig (encoding 0xd5033fdf). ~30 min.
