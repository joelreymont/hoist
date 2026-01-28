---
title: Implement getOperands() for ret
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T16:49:52.845403+02:00"
closed-at: "2026-01-05T17:01:27.297100+02:00"
---

File: src/backends/aarch64/inst.zig - In getOperands() method, add ret case: no operands to collect (implicit use of X30/LR handled by ABI). Match Cranelift aarch64 ret pattern. ~1 LOC.
