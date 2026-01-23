---
title: Wire external symbol resolution
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:05:45.814139+02:00\""
closed-at: "2026-01-24T00:10:05.644678+02:00"
---

Files: src/backends/aarch64/isle_helpers.zig:3753-3763
What: Implement ExternalName to symbol mapping
Currently: Stubbed with 'proper symbol resolution TBD'
Fix: Hook into Module's symbol table for lookups
Deps: hoist-add-module-struct-53230efc
Verification: External calls resolve to correct addresses
