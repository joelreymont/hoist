---
title: Emit x64 mem
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.360407+02:00\""
closed-at: "2026-01-23T10:14:45.523867+02:00"
---

Files: src/backends/x64/emit.zig:11-80
Root cause: no load/store encoders.
Fix: add mov/lea load/store encoders with ModRM/SIB.
Why: load/store lowering.
Deps: Emit x64 modrm, Add x64 mem.
Verify: load/store encoding tests.
