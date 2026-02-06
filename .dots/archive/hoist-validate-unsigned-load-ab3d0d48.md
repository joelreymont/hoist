---
title: Validate unsigned load/store immediates
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T21:57:25.804635+01:00\\\"\""
closed-at: "2026-02-06T22:01:36.203253+01:00"
close-reason: Added imm12 validation helper + regressions for byte/half/word unsigned forms
---

src/backends/aarch64/emit.zig: ldrb/ldrh/ldrsb/ldrsh/ldrsw/strb/strh currently truncate i16 offset into imm12 fields without range/alignment checks. Add helper validation (non-negative, alignment, imm12 bounds) and regression tests for OffsetOutOfRange/OffsetNotAligned.
