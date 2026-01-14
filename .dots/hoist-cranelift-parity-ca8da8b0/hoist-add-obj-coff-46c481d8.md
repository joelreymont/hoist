---
title: Add object coff
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.630146+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/object/README.md:1-4, src/machinst/reloc.zig:5-90
Root cause: no COFF object emission.
Fix: add src/object/coff.zig for Windows targets.
Why: Windows parity with Cranelift.
Deps: Add module symbols.
Verify: COFF writer tests.
