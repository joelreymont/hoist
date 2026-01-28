---
title: Implement vconst vector constant
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:27:38.371157+02:00"
closed-at: "2026-01-06T22:42:55.085828+02:00"
---

File: src/codegen/compile.zig - Add lowering for vconst. Load vector constant, likely from literal pool using LDR (SIMD). Or construct using MOVI for simple patterns. P1 operation.
