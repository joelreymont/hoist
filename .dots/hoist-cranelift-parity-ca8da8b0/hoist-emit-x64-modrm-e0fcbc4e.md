---
title: Emit x64 modrm
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.348476+02:00\""
closed-at: "2026-01-23T10:13:14.057675+02:00"
---

Files: src/backends/x64/emit.zig:11-80
Root cause: ModRM/SIB handling is incomplete.
Fix: implement ModRM/SIB encoding for reg/mem and scale/index/disp forms.
Why: all memory operands depend on it.
Deps: Add x64 mem.
Verify: encoding tests for ModRM/SIB forms.
