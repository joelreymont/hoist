---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:43:59.584906+02:00"
closed-at: "2026-01-01T09:05:26.834816+02:00"
close-reason: Replaced with correctly titled task
---

Port register framework from cranelift/codegen/src/machinst/{reg.rs,valueregs.rs} (~600 LOC). Create src/machinst/regs.zig with Reg, VReg, ValueRegs, RegClass, WritableReg. Depends on: entity (hoist-474de68d56804654). Files: src/machinst/regs.zig, regs_test.zig. Virtual and physical register representation.
