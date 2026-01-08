---
title: Implement DW_CFA_def_cfa opcode
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T21:25:43.996141+02:00"
---

File: src/backends/aarch64/unwind.zig. Add emitDefCfa(reg, offset) -> []u8. Encode DW_CFA_def_cfa (0x0c) + ULEB128(reg) + ULEB128(offset). Defines CFA as SP+offset. ~10 min.
