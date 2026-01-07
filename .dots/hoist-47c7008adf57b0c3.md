---
title: Lower fcvt_to_uint_sat, fcvt_to_sint_sat
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:11:33.429091+02:00"
closed-at: "2026-01-07T10:29:59.941436+02:00"
---

File: src/generated/aarch64_lower_generated.zig add patterns
Opcodes: fcvt_to_uint_sat, fcvt_to_sint_sat
Implementation (~50 lines each): Similar to fcvt_to_uint/sint but with saturation, emit fcvtzs/fcvtzu, handle overflow - clamp to min/max integer value
Dependencies: fcvt_to_uint/sint dot
Estimated: 1 day
Test: Test saturation behavior
