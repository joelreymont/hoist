---
title: Add clif tests
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.816800+02:00\""
closed-at: "2026-01-24T15:57:54.822609+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/docs/testing.md:23-75
Root cause: no clif test corpus.
Fix: add filetests for legalizer, lowering, regalloc, emit.
Why: coverage parity with Cranelift.
Deps: Add clif harness.
Verify: clif test runs.
