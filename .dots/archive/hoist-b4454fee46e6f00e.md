---
title: Add struct_load/struct_store IR opcodes
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T08:19:09.880334+02:00\""
closed-at: "2026-01-09T12:34:53.270037+02:00"
---

Add struct_load and struct_store opcodes to src/ir/opcodes.zig. Unary ops: struct_load takes pointer, struct_store takes pointer+value. Add to builder.zig. Prepare for field access lowering. ~20 min.
