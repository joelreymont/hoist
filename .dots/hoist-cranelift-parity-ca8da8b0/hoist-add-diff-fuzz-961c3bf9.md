---
title: Add diff fuzz
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.828626+02:00\""
closed-at: "2026-01-24T17:12:01.516381+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/README.md:46-50, fuzz/fuzz_compile.zig:1-120
Root cause: fuzzing is not differential.
Fix: compare JIT vs interpreter results and add crash minimization.
Why: parity with Cranelift fuzzing rigor.
Deps: Add ir interp.
Verify: fuzz step.
