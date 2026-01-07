---
title: Implement FP sign manipulation
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:33.120279+02:00"
closed-at: "2026-01-05T23:34:06.467475+02:00"
---

File: src/codegen/lower_aarch64.zig. Opcodes: fneg, fabs, fcopysign. Instructions: FNEG (negate), FABS (absolute value), fcopysign via ORR+BIC (copy sign bit). Single instructions. Dependencies: FP register handling. Effort: 4 hours.
