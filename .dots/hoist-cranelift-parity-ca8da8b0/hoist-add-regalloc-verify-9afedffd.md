---
title: Add regalloc verify
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.834594+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/README.md:46-50
Root cause: no symbolic regalloc verification.
Fix: add verifier that checks allocation validity against operand constraints.
Why: parity with Cranelift regalloc verification.
Deps: Wire regalloc2.
Verify: regalloc verification tests.
