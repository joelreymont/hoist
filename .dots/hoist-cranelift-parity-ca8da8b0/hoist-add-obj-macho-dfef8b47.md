---
title: Add object macho
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.624102+02:00\""
closed-at: "2026-01-23T15:13:11.496522+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/object/README.md:1-4, src/machinst/reloc.zig:5-90
Root cause: no Mach-O object emission.
Fix: add src/object/macho.zig for macOS targets.
Why: macOS parity with Cranelift.
Deps: Add module symbols.
Verify: Mach-O writer tests.
