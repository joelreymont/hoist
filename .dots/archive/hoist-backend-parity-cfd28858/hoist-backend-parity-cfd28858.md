---
title: Backend parity
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.820801+01:00\""
closed-at: "2026-02-06T10:37:14.958572+01:00"
close-reason: Completed backend parity regression dot tree
blocks:
  - hoist-add-dotprod-patterns-5f9c19ea
---

Context: src/codegen/compile.zig:4976-4990; cause: non-AArch64 lowering paths are TODO; fix: complete x64/riscv64/s390x lowering pipeline; deps: none; verification: zig build test (backend-specific)
