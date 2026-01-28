---
title: Add ARM64 fcvt_to_sint/uint trapping InstructionData
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T16:05:07.341033+02:00"
closed-at: "2026-01-03T16:55:01.673187+02:00"
---

File: src/ir/instruction_data.zig - Add UnaryWithTrap variant to InstructionData union (~20 LOC) - Trap code is bad_conversion_to_integer (255) already exists in trapcode.zig:31 - Needed for fcvt_to_sint/uint opcodes (opcodes.zig:167,169) - Accept: Can create instructions with trap metadata
