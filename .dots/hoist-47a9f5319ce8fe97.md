---
title: Implement sextend/uextend lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:28.978417+02:00"
closed-at: "2026-01-05T22:40:33.753379+02:00"
---

File: src/codegen/lower_aarch64.zig. Opcodes: sextend, uextend. Instructions: SXTB/SXTH/SXTW for sextend, UXTB/UXTH for uextend. Required for ABI parameter passing (i8→i64, etc.) and type casts. Dependencies: none. Effort: 1 day.
