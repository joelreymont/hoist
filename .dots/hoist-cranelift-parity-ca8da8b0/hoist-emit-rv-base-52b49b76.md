---
title: Emit rv base
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.406962+02:00"
---

Files: docs/architecture/06-backends.md:11-18, src/backends/x64/emit.zig:11-30
Root cause: no riscv64 emitter.
Fix: add src/backends/riscv64/emit.zig with RV64I encodings.
Why: generate machine code.
Deps: Add rv insts.
Verify: RV64I encoding tests.
