---
title: Add StructType to ir/types.zig
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-26T11:09:26.302184+01:00\""
closed-at: "2026-01-26T11:17:34.212937+01:00"
---

File: src/ir/types.zig
Add new struct type representation:
- pub const StructType = struct { fields: []const StructField }
- pub const StructField = struct { ty: Type, offset: u32 }
- Add STRUCT_BASE constant for encoding
- Add isStruct() method
Verify: zig build test -Dtest-filter=types
