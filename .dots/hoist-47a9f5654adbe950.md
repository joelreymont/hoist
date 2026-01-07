---
title: Implement FP fused multiply-add
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:32.365285+02:00"
closed-at: "2026-01-05T23:41:55.441858+02:00"
---

File: src/codegen/lower_aarch64.zig. Opcode: fma. Instructions: FMADD (a*b+c), FMSUB (a*b-c). Fused operation is more accurate (no intermediate rounding) and faster than separate MUL+ADD. Dependencies: FP register handling (already in place). Effort: 4 hours.
