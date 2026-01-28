---
title: "IR: instructions"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T10:59:36.791697+02:00\""
closed-at: "\"2026-01-01T11:43:12.980863+02:00\""
close-reason: "\"Split into smaller tasks: opcodes, formats, instruction data\""
blocks:
  - hoist-474fcfeed205f4fa
---

src/ir/instructions.zig (~2.5k LOC)

Port from: cranelift/codegen/src/ir/instructions.rs + generated

Implements:
- Opcode enum: ~200 opcodes (iadd, isub, load, store, call, jump, etc.)
- InstructionData: tagged union of instruction formats
  - Unary, Binary, Ternary
  - Load, Store
  - Call, CallIndirect
  - Jump, Branch, BranchTable
  - etc.
- InstructionFormat: describes operand layout
- OpcodeInfo: opcode properties (is_branch, is_terminator, etc.)

Key insight: Cranelift uses ISLE to generate much of this. We need base definitions first, ISLE generates lowering rules later.
