---
title: Fix extname call
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.577138+02:00"
---

Files: src/backends/aarch64/isle_helpers.zig:3753-3763
Root cause: ExternalName->symbol mapping is stubbed.
Fix: use ExternalName data to produce stable symbol names and relocations.
Why: correct external calls and object emission.
Deps: none.
Verify: call lowering tests.
