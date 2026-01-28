---
title: Implement FP min/max operations
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:32.741916+02:00"
closed-at: "2026-01-05T23:34:06.464375+02:00"
---

File: src/codegen/lower_aarch64.zig. Opcodes: fmin, fmax. Instructions: FMIN, FMAX. IEEE 754 NaN propagation semantics (important). Used in math libraries, clamping. Dependencies: FP register handling. Effort: 4 hours.
