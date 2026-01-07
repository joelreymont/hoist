---
title: Lower 32-bit memory opcodes
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:09:20.979371+02:00"
closed-at: "2026-01-07T10:07:13.212957+02:00"
---

File: src/generated/aarch64_lower_generated.zig add to .load/.store switch
Opcodes: uload32, sload32, istore32
Implementation (~25 lines each):
- uload32: ldr with W register (32-bit unsigned)
- sload32: ldrsw (32-bit signed → 64-bit)
- istore32: str with W register
Dependencies: None
Estimated: 4 hours
Test: Test 32-bit loads/stores
