---
title: dense rewrite alloc
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-18T10:37:37.335955+01:00\\\"\""
closed-at: "2026-02-18T10:42:22.305743+01:00"
close-reason: "discarded: best repeat-9 gain <5%"
---

file:src/codegen/compile.zig:586-6750; cause: rewriteRegisters/RegMapper performs AutoHashMap lookups per operand via getPhysReg/getSpillSlot in hot rewrite stage; fix: add dense vreg->preg/spill lookup tables built once per function and use in RegMapper paths; why: reduce hash-probe overhead in single-thread compile hot path with repeat-9 gate.
