---
title: RV decls
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-02T23:54:49.911238+01:00\\\"\""
closed-at: "2026-02-03T11:18:04.109576+01:00"
close-reason: Added Riscv64Inst and rv_* decls in riscv64/lower.isle
blocks:
  - hoist-a64-decls-081ab3b0
---

File: src/backends/riscv64/lower.isle:1; cause: rv_* term decls and inst type missing; fix: add Riscv64Inst type and rv_* ctor decls; why: riscv64 ISLE lowering must compile.
