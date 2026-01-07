---
title: Add sadd_overflow_cin lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.809664+02:00"
closed-at: "2026-01-06T08:43:49.659800+02:00"
---

File: compile.zig. Lower sadd_overflow_cin to ADDS+ADCS sequence for multi-word addition. Emit ADDS for low word (sets carry), ADCS for high word (consumes carry). Returns ValueRegs with result+overflow. Depends on: ADCS instruction variant. ARM64: ADDS+ADCS. Effort: 25 min.
