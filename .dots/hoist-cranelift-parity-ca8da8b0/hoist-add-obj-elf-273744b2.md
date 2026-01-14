---
title: Add object elf
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.618030+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/object/README.md:1-4, src/machinst/reloc.zig:5-90
Root cause: no object file emission.
Fix: add src/object/elf.zig to emit ELF with relocations.
Why: object backend parity.
Deps: Add module symbols.
Verify: object writer tests.
