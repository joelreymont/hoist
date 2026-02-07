---
title: Harden a64 operand collection
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-07T09:38:40.876904+01:00\""
closed-at: "2026-02-07T09:41:57.612689+01:00"
close-reason: completed
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/inst.zig getOperands() has default else that silently drops operands for unhandled instruction variants. Cause: silent fallback can hide regalloc/liveness bugs when new Inst variants are added without operand metadata. Fix: make unhandled variants fail explicitly and add/adjust tests so supported variants are covered. Verification: zig build test -j1 --global-cache-dir .zig-global-cache and zig build fuzz.
