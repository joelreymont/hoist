---
title: Emit s390 base
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.471368+02:00"
---

Files: docs/architecture/06-backends.md:11-18, src/backends/x64/emit.zig:11-30
Root cause: no s390x emitter.
Fix: add src/backends/s390x/emit.zig with base ALU/branch/mem encodings.
Why: generate machine code.
Deps: Add s390 insts.
Verify: base encoding tests.
