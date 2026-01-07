---
title: "machinst: registers"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T11:00:55.676192+02:00\""
closed-at: "\"2026-01-01T16:10:41.401659+02:00\""
close-reason: Completed machinst register abstractions (~304 LOC) - RegClass, PReg, VReg, Reg, WritableReg, SpillSlot, ValueRegs with all tests passing
blocks:
  - hoist-474fd1b1ac3b1a59
---

src/machinst/reg.zig (~600 LOC)

Port from: cranelift/codegen/src/machinst/{reg,valueregs}.rs

Register abstraction layer:
- Reg: physical register (encoded as u8, includes class)
- VReg: virtual register (u32 index + class)
- WritableReg: newtype for def vs use tracking
- ValueRegs: 1-2 registers for wide values (i128, f64 on 32-bit)

RegClass enum:
- Int (GPR)
- Float (XMM/NEON)
- Vector (for explicit SIMD)

PReg (physical register):
- Encoded with class + hw_enc
- is_stack() for spill slots
- Architecture-specific register files

Key for regalloc integration - must match regalloc2 interface
