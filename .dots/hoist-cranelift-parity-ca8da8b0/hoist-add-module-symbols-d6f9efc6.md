---
title: Add module symbols
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.612135+02:00"
---

Files: src/machinst/reloc.zig:5-90
Root cause: reloc table exists but no module symbol table/linking.
Fix: add symbol table and relocation planning for functions/data.
Why: module linking support.
Deps: Add module api.
Verify: symbol resolution tests.
