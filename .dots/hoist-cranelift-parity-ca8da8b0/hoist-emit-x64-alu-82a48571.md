---
title: Emit x64 alu
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.354374+02:00"
---

Files: src/backends/x64/emit.zig:17-80
Root cause: only add/sub reg-reg encodings exist.
Fix: implement ALU encodings for reg/imm/mem and cmp/test.
Why: integer ops lowering.
Deps: Emit x64 modrm, Add x64 alu.
Verify: ALU encoding tests.
