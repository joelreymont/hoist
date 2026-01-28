---
title: Test stack alignment
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:09:37.310206+02:00"
closed-at: "2026-01-07T07:34:47.374237+02:00"
---

File: tests/abi_stack_align.zig - Test: call with >8 args (uses stack). Verify: stack 16-byte aligned before call, args at correct offsets. Use misaligned stack detector (compile with -fsanitize=alignment or manual check). AAPCS64 requires 16-byte at public interfaces. Dependencies: hoist-47b48713603148cd.
