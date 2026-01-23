---
title: Fix external name lookup
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:54:35.289482+02:00\""
closed-at: "2026-01-24T00:56:48.320989+02:00"
---

In src/backends/aarch64/isle_impl.zig:2254, replace @panic with proper ExternalName->symbol lookup. Use Module symbol table. Deps: Add symbol table to Module. Verify: zig build test
