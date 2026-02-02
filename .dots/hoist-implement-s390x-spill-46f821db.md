---
title: Implement s390x spill/reload
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.841878+01:00"
blocks:
  - hoist-implement-riscv64-vreg-58fe8426
---

Context: src/backends/s390x/isa.zig:186; cause: spill/reload insertion TODO; fix: implement spill/reload pass for s390x; deps: none; verification: add s390x ISA tests + zig build test
