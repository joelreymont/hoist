---
title: Add calling convention ABI tests
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:32:44.165381+02:00"
closed-at: "2026-01-07T08:07:11.215584+02:00"
---

File: src/backends/aarch64/abi_callconv_test.zig (new). Test each calling convention: (1) Fast - verify >8 int args in registers, (2) PreserveAll - verify all GPRs/FPRs saved, (3) Cold - verify attribute set, (4) Darwin X18 - verify never allocated, (5) Darwin red zone - verify frame created for leaf. ~150 lines total. Depends: all ABI variant dots.
