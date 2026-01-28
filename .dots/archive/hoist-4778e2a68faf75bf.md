---
title: Fix remaining 36 Zig 0.15 errors - type mismatches, field names, ArrayList ops
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T11:59:44.478135+02:00"
closed-at: "2026-01-03T12:02:00.180232+02:00"
close-reason: Duplicate of 4778e3b800173d49
---

Current error count: 36 (29 unique types)

Categories:
- PrimaryMap.get() return type pointer vs optional mismatches in domtree.zig
- Field name changes: Offset32.offset, Imm64.bits
- ArrayList append/deinit allocator parameters
- ExternalName union tag access
- Opcode.copy missing
- JumpTable API changes
- Backend trait type mismatches
- Ambiguous format strings

Files affected:
- src/ir/domtree.zig - PrimaryMap.get() type issues
- src/ir/global_value_data.zig - immediate field names
- src/ir/instruction_data.zig - missing Opcode.copy
- src/ir/jump_table_data.zig - API signature changes
- src/ir/loops.zig - ArrayList operations
- src/machinst/backend.zig - trait type mismatches

Strategy: Fix field names first (simple), then type mismatches, then complex API issues
