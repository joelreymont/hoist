---
title: Add extended_value extractor
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T15:04:56.396504+02:00"
---

Files: src/backends/aarch64/isle_impl.zig
What: Add extended_value_from_value to fold sign/zero extend into arithmetic
Purpose: Pattern like (iadd x (sextend y)) -> ADD with SXTW operand
Saves instruction by using extended register form
Verification: Test with extend + arithmetic patterns
