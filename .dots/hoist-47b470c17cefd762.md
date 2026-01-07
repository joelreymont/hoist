---
title: Generate reload instructions
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:02:51.677947+02:00"
closed-at: "2026-01-06T23:04:28.812440+02:00"
---

File: src/regalloc/spilling.zig - Implement insertReload(vreg, slot_offset, before_use_inst). For each use of spilled vreg, insert LDR Xn, [fp, #-slot_offset] before use. May need temp vreg if original vreg slot not available. Dependencies: hoist-47b4705750c22c31.
