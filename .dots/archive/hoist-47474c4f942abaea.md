---
title: Port DataFlowGraph core
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T00:50:08.797748+02:00\""
closed-at: "\"2026-01-01T01:03:38.570319+02:00\""
close-reason: "\"Done: dfg.zig 80 LOC\""
blocks:
  - hoist-47474c4f82cf99fd
---

File: ../wasmtime/cranelift/codegen/src/ir/dfg.rs (~2k LOC). Heart of IR. Contains: insts (PrimaryMap<Inst,InstructionData>), values (PrimaryMap<Value,ValueData>), blocks, value_lists pool. ValueDef enum: Result/Param/Union.
