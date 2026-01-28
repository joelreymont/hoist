---
title: Generate prologue argument moves
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T22:42:28.052639+02:00"
closed-at: "2026-01-06T22:57:52.868465+02:00"
---

File: src/backends/aarch64/compile.zig - Use ABI classification to generate prologue code moving arguments from parameter locations to vregs. In emitAArch64WithAllocation: 1) Call classifyArgs for function signature, 2) For each Reg argument, emit move from parameter register to allocated vreg, 3) For each Stack argument, emit load from stack slot to allocated vreg, 4) Insert moves before first instruction
