---
title: Add type conversion InstructionData variants
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T14:54:26.428128+02:00"
closed-at: "2026-01-03T15:46:59.057087+02:00"
close-reason: Already completed - documented that type conversions use existing UnaryData/BinaryData variants. iconcat uses BinaryData, isplit uses UnaryData + InsnColor.multi_result
---

File: src/ir/instruction_data.zig - Extend existing variants: Unary for sextend/uextend/ireduce/fpromote/fdemote/fcvt_*, Binary for iconcat (2 inputs → 1 i128), special handling for isplit (1 i128 input → 2 i64 results using existing InsnColor.multi_result from vcode_builder.zig:43) - Accept: All conversion opcodes have InstructionData variants, DFG supports multi_result for isplit - Depends: 'Add type conversion opcodes to IR'
