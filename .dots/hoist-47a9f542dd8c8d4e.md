---
title: Implement select lowering (CSEL)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:30.109078+02:00"
closed-at: "2026-01-05T22:42:49.850735+02:00"
---

File: src/codegen/lower_aarch64.zig. Opcode: select. Instruction: CSEL (conditional select). Branchless if-then-else, fundamental operation. Pattern: select(cond, true_val, false_val) → CMP + CSEL. Dependencies: condition code handling. Effort: 1 day.
