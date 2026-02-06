---
title: Implement riscv64 vreg rewrite
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.834908+01:00\""
closed-at: "2026-02-06T11:27:19.450740+01:00"
close-reason: Implemented vreg rewrite in riscv64 ISA.
blocks:
  - hoist-implement-riscv64-spill-9f9796e2
---

Context: src/backends/riscv64/isa.zig:192; cause: vreg->preg rewrite TODO; fix: implement rewrite pass after regalloc; deps: Implement riscv64 spill/reload; verification: riscv64 codegen tests
