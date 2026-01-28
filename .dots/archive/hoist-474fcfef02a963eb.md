---
title: "IR: layout/CFG"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T10:59:36.799925+02:00\""
closed-at: "\"2026-01-01T14:32:09.176660+02:00\""
close-reason: Completed Layout with block/inst linked lists, iterators, all operations and tests passing
blocks:
  - hoist-474fcfeed205f4fa
---

src/ir/layout.zig (~1.5k LOC)

Port from: cranelift/codegen/src/ir/layout.rs

Layout - block and instruction ordering:
- blocks: linked list of Block (first_block, last_block)
- block_data: SecondaryMap<Block, BlockData> with first/last inst
- inst_data: SecondaryMap<Inst, InstData> with prev/next, block
- Uses bforest for ordered iteration

Key operations:
- append_block(block)
- insert_inst(inst, after)
- remove_inst(inst)
- block_insts(block) -> iterator
- inst_block(inst) -> Block

CFG (control flow graph):
- Computed from branch instructions
- pred_iter(block), succ_iter(block)
- Invalidated on layout changes, recomputed lazily
