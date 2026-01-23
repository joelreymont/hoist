---
title: Emit x64 atom
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.377812+02:00\""
closed-at: "2026-01-23T10:36:02.152887+02:00"
---

Files: src/backends/x64/emit.zig:11-30
Root cause: atomic encoding is missing.
Fix: add lock prefix encoding and cmpxchg/xadd forms.
Why: atomic RMW correctness.
Deps: Add x64 atom, Emit x64 modrm.
Verify: atomic encoding tests.
