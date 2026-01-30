---
title: Add call layout
status: active
priority: 1
issue-type: task
created-at: "\"2026-01-30T18:12:33.784356+01:00\""
---

Context: src/backends/aarch64/abi.zig:712; cause: no shared AAPCS64 call layout, stack size computed ad hoc; fix: add CallLayout builder with arg locs + stack size using StructStore + alignment; deps: none; verification: add unit tests for stack arg space and struct/HFA placement
