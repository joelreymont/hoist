---
title: Implement riscv64 vreg rewrite
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.834908+01:00"
blocks:
  - hoist-implement-riscv64-spill-9f9796e2
---

Context: src/backends/riscv64/isa.zig:192; cause: vreg->preg rewrite TODO; fix: implement rewrite pass after regalloc; deps: Implement riscv64 spill/reload; verification: riscv64 codegen tests
