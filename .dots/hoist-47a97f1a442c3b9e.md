---
title: Implement shifts (LSL/LSR/ASR)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:27.736886+02:00"
closed-at: "2026-01-05T23:22:18.922105+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower ishl/ushr/sshr IR opcodes to LSL/LSR/ASR instructions. Handle immediate and register shift amounts. Support 32-bit and 64-bit variants. Reference: Cranelift lower.isle shift patterns. Part of Phase 2 core functionality. Estimate: 1 day.
