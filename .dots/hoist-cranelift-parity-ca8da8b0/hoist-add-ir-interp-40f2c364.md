---
title: Add ir interp
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.846025+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/interpreter/README.md:1-2
Root cause: no IR interpreter exists.
Fix: add src/interpreter/interpreter.zig to execute IR control flow and int ops.
Why: parity with Cranelift interpreter and test oracle.
Deps: none.
Verify: interpreter unit tests.
