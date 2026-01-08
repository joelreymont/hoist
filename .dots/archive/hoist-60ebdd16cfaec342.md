---
title: Implement CFA opcodes
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T21:19:55.152298+02:00\""
closed-at: "2026-01-08T21:25:37.592200+02:00"
---

File: src/backends/aarch64/unwind.zig. Implement DW_CFA_def_cfa (SP+offset), DW_CFA_offset (save register), DW_CFA_remember/restore_state for prologue/epilogue. Emit byte sequences for each opcode. ~20 min.
