---
title: "machinst: VCode"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T11:00:55.684629+02:00\""
closed-at: "\"2026-01-01T16:15:24.169603+02:00\""
close-reason: Completed VCode (~291 LOC) - virtual-register CFG with blocks, instructions, successor/predecessor computation, block parameters with all tests passing
blocks:
  - hoist-474fd4a2a1a47a15
---

src/machinst/vcode.zig (~1.5k LOC)

Port from: cranelift/codegen/src/machinst/vcode.rs

VCode - virtual-register machine code:
- insts: []MachInst (flattened instruction list)
- blocks: []VCodeBlock (block boundaries)
- block_order: []BlockIndex (layout order)
- vreg_types: []Type (virtual register types)
- entry_block: BlockIndex
- abi: ABI implementation

VCodeBlock:
- start/end instruction indices
- successors/predecessors
- block params

Key operations:
- emit_inst(inst)
- end_block()
- set_vreg_type(vreg, ty)

After lowering, before regalloc: all regs are virtual
