---
title: "P2.1: Implement I128 arithmetic operations"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T08:30:41.312651+02:00"
closed-at: "2026-01-04T08:33:12.147037+02:00"
---

Implement I128 iadd/isub/imul/ineg/iabs using register pairs. ARM64 approach: low 64 + high 64 in separate registers, use ADDS/ADC for iadd (with carry), SUBS/SBC for isub. Study Cranelift's implementation. Est: 12-24h for 5 ops. Critical for correctness.
