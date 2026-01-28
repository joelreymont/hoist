---
title: Pre-allocate VRegs for all SSA values before lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:08:46.828039+02:00"
closed-at: "2026-01-07T09:15:49.323250+02:00"
---

File: src/machinst/lower.zig lines 49-66 (LowerCtx.init)
Currently: VRegs allocated on-demand via getValueReg()
Need: Iterate all IR instructions/block params, allocate VRegs upfront
Why: Enables vreg aliasing (ISLE temps → SSA vregs), matches Cranelift model
Implementation:
1. Add allocateSSAVRegs() method to LowerCtx
2. Before lowering loop, iterate func.dfg.insts, call allocVReg for each result
3. Store in value_to_reg map
4. Iterate all blocks, allocate VRegs for block params
Dependencies: None
Estimated: 1 day
Test: lower_test.zig - verify VRegs pre-allocated
