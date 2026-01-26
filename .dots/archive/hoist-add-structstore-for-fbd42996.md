---
title: Add StructStore for type interning
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-26T11:09:33.614730+01:00\""
closed-at: "2026-01-26T11:17:34.218540+01:00"
---

File: src/ir/types.zig
Add hash-consed storage for struct types:
- pub const StructId = enum(u16) { _ }
- StructStore with getOrPut/intern methods
- Store fields in contiguous buffer
Deps: hoist-add-structtype-to-9e0d05d5
Verify: zig build test -Dtest-filter=types
