---
title: "machinst: lowering"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T11:00:55.700176+02:00\""
closed-at: "\"2026-01-01T16:37:59.977939+02:00\""
close-reason: "\"Created lower.zig (~216 LOC) with LowerCtx generic context, value-to-vreg mapping, LowerBackend trait, and lowerFunction driver. Simplified bootstrap version - deferred side-effect tracking, liveness, sinking. All 11 tests pass. Total: ~11.2k LOC\""
blocks:
  - hoist-474fd4a2dfb53f75
---

src/machinst/lower.zig (~2k LOC)

Port from: cranelift/codegen/src/machinst/lower.rs

LowerCtx - IR to MachInst lowering:
- func: *Function (input IR)
- vcode: *VCode (output being built)
- current_block: BlockIndex

ISLE integration:
- get_opcode(inst) -> Opcode
- get_arg(inst, idx) -> Value
- put_in_reg(value) -> VReg
- emit(machinst)

Lowering flow:
1. For each IR block in RPO
2. For each instruction
3. Call ISLE-generated lower() function
4. Emit resulting MachInsts

Value handling:
- Track which Values are in which VRegs
- Handle multi-result instructions
- Materialize constants as needed
