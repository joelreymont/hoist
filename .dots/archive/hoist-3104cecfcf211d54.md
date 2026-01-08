---
title: Implement DW_CFA_offset opcode
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T21:25:48.282861+02:00"
---

File: src/backends/aarch64/unwind.zig. Add emitOffset(reg, offset) -> []u8. Encode DW_CFA_offset (0x80 | reg) + ULEB128(offset/data_align). Saves register at CFA+offset. ~10 min.
