---
title: Lower sextend, uextend, ireduce opcodes
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:09:20.968386+02:00"
closed-at: "2026-01-07T10:06:30.662680+02:00"
---

File: src/generated/aarch64_lower_generated.zig add to .unary switch
Opcodes: sextend (sign extend), uextend (zero extend), ireduce (truncate)
Implementation:
- sextend: Check input/output sizes, emit sxtb/sxth/sxtw (~40 lines)
- uextend: emit uxtb/uxth or ubfm (~40 lines)
- ireduce: Just mov or extract bits (~30 lines)
Dependencies: None
Estimated: 1 day
Test: Test 8→16, 8→32, 8→64, 16→32, 16→64, 32→64 for each
