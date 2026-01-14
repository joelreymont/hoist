---
title: Extend value regs
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.559727+02:00"
---

Files: src/machinst/reg.zig:191-226
Root cause: ValueRegs only supports 1-2 registers.
Fix: extend ValueRegs to support >2 regs with sized array or slice.
Why: multi-return and large values.
Deps: none.
Verify: update ValueRegs tests in src/machinst/reg.zig.
