---
title: Add jit module
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.647285+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/jit/README.md:1-6
Root cause: no JIT module implementation.
Fix: add src/jit/module.zig implementing Module interface with reloc application.
Why: JIT backend parity.
Deps: Add module api, Add module symbols, Add jit memory.
Verify: JIT module tests.
