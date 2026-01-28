---
title: "IR: entities"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T10:59:36.787476+02:00\""
closed-at: "\"2026-01-01T11:42:47.657962+02:00\""
close-reason: Implemented IR entity references using existing EntityRef abstraction
blocks:
  - hoist-474fcfeebcd92b9e
---

src/ir/entities.zig (~800 LOC)

Port from: cranelift/codegen/src/ir/entities.rs

Entity reference types (all use entity.EntityRef):
- Value: SSA value reference
- Inst: instruction reference  
- Block: basic block reference
- FuncRef: external function reference
- SigRef: function signature reference
- GlobalValue: global variable reference
- StackSlot: stack slot reference
- JumpTable: jump table reference
- Constant: constant pool reference

Each is a u32 newtype with formatting (v0, inst5, block3, etc.)
