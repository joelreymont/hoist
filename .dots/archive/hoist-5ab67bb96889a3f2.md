---
title: Implement bitcast opcode
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T06:47:40.044623+02:00\""
closed-at: "2026-01-09T06:55:55.569522+02:00"
---

CRITICAL: Add bitcast IR opcode for float<->int reinterpretation without memory. Files: (1) src/ir/opcodes.zig - add Bitcast variant, (2) src/backends/aarch64/lower.isle - add lowering rule using FMOV between scalar and vector regs, (3) src/backends/aarch64/isle_helpers.zig - implement aarch64_bitcast helper. Example: bitcast i32 0x3f800000 -> f32 1.0. Small effort, foundational for correctness.
