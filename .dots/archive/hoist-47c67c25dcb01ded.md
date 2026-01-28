---
title: Implement brif lowering for aarch64
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T08:34:32.216768+02:00"
closed-at: "2026-01-07T08:51:40.151180+02:00"
---

File: src/backends/aarch64/lower.zig lowerBranch() function. Add pattern: if inst_data is .branch and opcode is .brif: (1) Get cond value → vreg, (2) Emit cmp against zero (cmp_imm vreg, 0), (3) Get then/else block labels, (4) Emit b.ne to then_block, (5) Emit b to else_block, (6) Return true. Use BranchData. ~30 lines. Depends on: hoist-47c67bb5b77497c4.
