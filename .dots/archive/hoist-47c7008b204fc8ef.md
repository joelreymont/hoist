---
title: Lower bitcast, raw_bitcast
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:11:33.445724+02:00"
closed-at: "2026-01-07T10:09:10.244520+02:00"
---

File: src/generated/aarch64_lower_generated.zig add patterns
Opcodes: bitcast, raw_bitcast (reinterpret bits between int/float)
Implementation (~25 lines each): Use fmov between general and SIMD/FP registers, handle different sizes
Dependencies: None
Estimated: 4 hours
Test: Test int↔float bitcasts
