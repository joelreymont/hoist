---
title: Fix FP unary/frint
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"\\\\\\\"\\\\\\\\\\\\\\\"2026-01-14T14:14:40.833424+02:00\\\\\\\\\\\\\\\"\\\\\\\"\\\"\""
closed-at: "2026-01-14T14:26:15.065053+02:00"
close-reason: add fmax/fmin emit cases
---

Files: src/backends/aarch64/emit.zig:4355-4665, tests at 10628-11210. Root cause: fneg/fabs opcode fields incorrect; frintp/frintm rmode values swapped; fadd S expected constant off by 0x1000. Fix: update opcode fields to match assembler encodings, swap rmode constants, update fadd single expected value. Why: correct FP encodings and unblock tests.
