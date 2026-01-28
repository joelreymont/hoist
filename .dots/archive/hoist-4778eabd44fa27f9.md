---
title: Fix remaining 33 Zig 0.15 errors - domtree types, JumpTable, backend traits
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T12:02:00.184066+02:00"
closed-at: "2026-01-03T12:09:47.678019+02:00"
---

Down to 33 errors from 77+!

Remaining categories:
1. domtree.zig - PrimaryMap.get() returns pointer but code expects optional (lines 151, 640, 212, 308)
2. jump_table_data.zig - API signature mismatches (3 errors needing allocator)
3. loops.zig - ArrayList.append needs allocator (line 659)
4. backend.zig - trait type signature mismatches (2 errors)
5. Ambiguous format strings - stdlib Writer errors

Next: Fix domtree type mismatches by dereferencing pointers or changing logic
