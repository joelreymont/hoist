---
title: Add Type.getStructFields method
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-26T11:09:39.125266+01:00\""
closed-at: "2026-01-26T11:17:34.225278+01:00"
---

File: src/ir/types.zig
Add method to get struct field info from Type:
- pub fn getStructFields(self: Type, store: *StructStore) ?[]const StructField
- Returns null for non-struct types
Deps: hoist-add-structstore-for-fbd42996
Verify: zig build test -Dtest-filter=types
