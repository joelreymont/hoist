---
title: Add interp fp
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.857719+02:00\""
closed-at: "2026-01-24T16:20:46.512587+02:00"
---

Files: src/interpreter/interpreter.zig (new)
Root cause: interpreter lacks FP ops.
Fix: implement f32/f64 ops, comparisons, and NaN rules.
Why: FP parity with Cranelift.
Deps: Add ir interp.
Verify: FP interpreter tests.
