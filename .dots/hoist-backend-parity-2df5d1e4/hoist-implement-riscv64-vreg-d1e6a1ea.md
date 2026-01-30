---
title: Implement riscv64 vreg rewrite
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:10:01.878540+01:00"
---

Context: src/backends/riscv64/isa.zig:192; cause: vreg->preg rewrite TODO; fix: implement rewrite pass after regalloc; deps: Implement riscv64 spill/reload; verification: riscv64 codegen tests
