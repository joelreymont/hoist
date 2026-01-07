---
title: Replace virtual registers with physical registers
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:10:15.365759+02:00"
closed-at: "2026-01-07T10:42:57.200871+02:00"
---

File: src/machinst/regalloc.zig add rewriteRegs()
Need: Walk all instructions, replace VRegs with allocated PRegs
Implementation: Iterate all instructions, get allocation from regalloc2::Output.allocs, rewrite instruction operands VReg → PReg
Dependencies: Previous regalloc dot
Estimated: 2 days
Test: Verify all VRegs replaced with PRegs
