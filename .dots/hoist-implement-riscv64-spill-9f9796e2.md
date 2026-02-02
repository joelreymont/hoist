---
title: Implement riscv64 spill/reload
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.828193+01:00"
blocks:
  - hoist-backend-parity-cfd28858
---

Context: src/backends/riscv64/isa.zig:186; cause: spill/reload insertion TODO; fix: implement spill/reload pass for riscv64; deps: none; verification: add riscv64 ISA tests + zig build test
