---
title: Cranelift parity
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:05:26.961456+02:00"
---

Context: ~/Work/wasmtime/cranelift/README.md:46-60 (backends, ABI), ~/Work/wasmtime/cranelift/docs/index.md:16-51 (frontend/native/reader/module/object/jit), ~/Work/wasmtime/cranelift/docs/testing.md:17-75 (filetests), /Users/joel/Work/hoist/docs/feature_gap_analysis.md:85-129 (missing regalloc/ABI/tests). Root cause: Hoist lacks parity with Cranelift backends, module/JIT/object, reader/tests, regalloc2/fuzzing, and advanced opts. Fix: implement missing subsystems, backends, and tests; update docs to match reality. Why: functional parity and ecosystem integration.
