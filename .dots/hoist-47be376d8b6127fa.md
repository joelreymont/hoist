---
title: Implement vconst vector constant
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T22:42:39.548272+02:00"
closed-at: "2026-01-07T06:12:39.441705+02:00"
---

File: src/backends/aarch64/lower.isle - Implement vconst lowering for vector constants. Strategy: 1) Check if constant is all zeros (use MOVI #0), 2) Check if constant is all ones (use MVNI #0), 3) Check if splat of single value (use DUP or MOVI with immediate), 4) Otherwise load from constant pool. Need constant pool infrastructure in compile.zig
