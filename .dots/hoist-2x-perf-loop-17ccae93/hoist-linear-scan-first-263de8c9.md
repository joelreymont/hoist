---
title: linear scan first-free fast
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T21:05:09.387700+01:00\\\"\""
closed-at: "2026-02-21T21:12:59.193931+01:00"
close-reason: "discarded: repeat-9 gate regressions on large(100)/large(500)"
---

Context: src/regalloc/linear_scan.zig tryAllocateReg linearly probes bitset for free regs; fix: use bitset iterator/toggle-first patterns to reduce probe overhead while preserving hint/callee-saved constraints.
