---
title: Add interp tests
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.869582+02:00\""
closed-at: "2026-01-24T17:09:08.835374+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/interpreter/README.md:1-2
Root cause: no interpreter test suite.
Fix: add tests for control flow, memory, FP, SIMD.
Why: correctness of interpreter.
Deps: Add ir interp, Add interp mem, Add interp fp, Add interp simd.
Verify: zig build test.
