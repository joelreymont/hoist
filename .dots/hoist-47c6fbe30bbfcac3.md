---
title: Lower select opcode
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:10:15.321549+02:00"
closed-at: "2026-01-07T09:50:52.749784+02:00"
---

File: src/generated/aarch64_lower_generated.zig add to .ternary switch
Opcode: select (condition ? true_val : false_val)
Implementation (~50 lines):
- Get condition, true_val, false_val operands
- Get their VRegs
- Emit cmp condition, 0 (test if non-zero)
- Emit csel dst, true_reg, false_reg, ne
Dependencies: None
Estimated: 4 hours
Test: Test select with various conditions
