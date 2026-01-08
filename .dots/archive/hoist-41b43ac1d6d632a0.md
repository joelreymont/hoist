---
title: Add fconst IR opcode
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T12:58:09.705266+02:00\""
closed-at: "2026-01-08T13:00:08.706797+02:00"
---

File: src/ir/opcodes.zig, instruction_data.zig - Add fconst opcode for floating-point constants. Add UnaryImmFloat instruction data (similar to UnaryImm for iconst). Store f32/f64 as u32/u64 bit patterns. Depends on: none. Blocks: FP constant loading. Enables: FP constant materialization in IR.
