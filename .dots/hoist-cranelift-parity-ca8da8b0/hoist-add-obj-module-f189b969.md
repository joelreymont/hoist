---
title: Add object module
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.636023+02:00\""
closed-at: "2026-01-23T15:14:33.983553+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/module/README.md:9-15
Root cause: no ObjectModule wrapper around object writers.
Fix: add src/object/module.zig implementing Module interface.
Why: cranelift-object parity.
Deps: Add object elf, Add object macho, Add object coff.
Verify: object module tests.
