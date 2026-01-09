---
title: Implement bmask opcode
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T06:47:47.224858+02:00\""
closed-at: "2026-01-09T07:01:41.581526+02:00"
---

MEDIUM: Add bmask IR opcode to convert boolean to all-ones/all-zeros bitmask. Files: (1) src/ir/opcodes.zig - add Bmask variant, (2) src/backends/aarch64/lower.isle - add lowering using CSETM (conditional set mask) or NEG, (3) tests for i8/i16/i32/i64/i128 mask generation. Used for SIMD select operations. Small effort, improves SIMD efficiency.
