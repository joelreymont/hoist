---
title: Add argument classification unit tests using MockABI
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:33:10.006997+02:00"
closed-at: "2026-01-07T07:57:16.224372+02:00"
---

File: src/backends/aarch64/arg_classification_test.zig (new). Test AAPCS64 arg passing: (1) int args X0-X7 then stack, (2) FP args V0-V7 then stack, (3) HFA (homogeneous float aggregate) in V regs, (4) large structs by reference, (5) 128-bit args in even register pairs. Use MockABI. ~120 lines. Depends: MockABI (hoist-47c59ffe5d59dbeb).
