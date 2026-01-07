---
title: "IR: function"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T10:59:36.804025+02:00\""
closed-at: "\"2026-01-01T15:07:46.141872+02:00\""
close-reason: Completed Function with stack_slots, global_values, jump_tables, entryBlock(), isLeaf(), all tests passing
blocks:
  - hoist-474fcfeef38daa0d
---

src/ir/function.zig (~800 LOC)

Port from: cranelift/codegen/src/ir/function.rs

Function - complete IR function:
- name: ExternalName
- signature: Signature (params, returns, calling convention)
- dfg: DataFlowGraph
- layout: Layout
- stack_slots: PrimaryMap<StackSlot, StackSlotData>
- global_values: PrimaryMap<GlobalValue, GlobalValueData>
- jump_tables: PrimaryMap<JumpTable, JumpTableData>

Additional:
- entry_block() -> Block
- is_leaf() -> bool (no calls)
- collect_debug_info()

Depends on: dfg, layout (both must be complete)
