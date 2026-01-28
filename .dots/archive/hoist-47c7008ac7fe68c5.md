---
title: Lower fcvt_from_uint, fcvt_from_sint
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:11:33.423114+02:00"
closed-at: "2026-01-07T10:24:45.009958+02:00"
---

File: src/generated/aarch64_lower_generated.zig add patterns
Opcodes: fcvt_from_uint, fcvt_from_sint
Implementation (~35 lines each): Get integer operand, allocate float destination, emit scvtf (signed) or ucvtf (unsigned), handle I32→F32, I32→F64, I64→F32, I64→F64 combinations
Dependencies: None
Estimated: 1 day
Test: Test all size combinations
