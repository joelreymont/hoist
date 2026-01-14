---
title: Module JIT
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:06:23.163154+02:00\""
closed-at: "2026-01-14T15:42:57.167822+02:00"
close-reason: split into small dots under hoist-cranelift-parity
---

Context: ~/Work/wasmtime/cranelift/docs/index.md:40-51 (module/object/jit crates), ~/Work/wasmtime/cranelift/module/README.md:1-15, ~/Work/wasmtime/cranelift/object/README.md:1-4, ~/Work/wasmtime/cranelift/jit/README.md:1-6, /Users/joel/Work/hoist/src/context.zig:30-92 (single-function compile), /Users/joel/Work/hoist/src/backends/aarch64/jit_harness.zig:1-120 (test-only JIT memory). Root cause: no module layer to link funcs/data, no JIT/object backends. Fix: add module API, object emitter integration, and JIT code/data manager. Why: parity with Cranelift module/jit/object.
