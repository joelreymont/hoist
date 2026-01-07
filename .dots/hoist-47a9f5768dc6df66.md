---
title: Implement FP comparisons
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:33.496534+02:00"
closed-at: "2026-01-05T23:41:55.446990+02:00"
---

File: src/codegen/lower_aarch64.zig. Opcode: fcmp. Instructions: FCMP (set condition flags) + CSET (materialize bool result). Handle FloatCC conditions (EQ, LT, LE, GT, GE, NE, ORD, UNO). Ordered vs unordered (NaN handling) critical. Dependencies: condition code handling. Effort: 1 day.
