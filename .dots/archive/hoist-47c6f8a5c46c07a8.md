---
title: Lower 8/16-bit memory opcodes
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:09:20.973947+02:00"
closed-at: "2026-01-07T10:06:54.039544+02:00"
---

File: src/generated/aarch64_lower_generated.zig add to .load/.store switch
Opcodes: uload8, sload8, istore8, uload16, sload16, istore16
Implementation (~25 lines each):
- uload8: ldrb (byte load unsigned)
- sload8: ldrsb (byte load signed)
- istore8: strb (byte store)
- uload16: ldrh (halfword load unsigned)
- sload16: ldrsh (halfword load signed)
- istore16: strh (halfword store)
Dependencies: None
Estimated: 1 day
Test: Test each size/signedness
