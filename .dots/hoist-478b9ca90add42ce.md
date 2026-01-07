---
title: "P2.8a: Implement lower_select helper"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T10:20:14.614256+02:00"
closed-at: "2026-01-04T12:27:54.324883+02:00"
---

File: src/backends/aarch64/lower.isle around line 2600 (after vec_cmp helpers) - Add lower_select helper with type-specific rules for I8/I32/I64/I128/F32/F64/F128/vectors. Takes ProducesFlags, Cond, Type, and two Values. Returns ValueRegs. Reference: Cranelift inst.isle lines 4600-4650.
