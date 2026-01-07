---
title: Add ARM64 SIMD lane manipulation
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T16:06:10.758682+02:00"
closed-at: "2026-01-03T16:33:49.883300+02:00"
---

File: src/backends/aarch64/lower.isle, isle_helpers.zig, inst.zig, instruction_data.zig - CRITICAL: Need InstructionData extension for lane index metadata - Opcodes EXIST: insertlane, extractlane, scalar_to_vector, extract_vector - Need: INS, UMOV, SMOV, DUP ARM64 instructions (~30 LOC inst.zig) - Need: Lowering rules with lane indexing (~200-300 LOC) - Need: Emit functions for lane-indexed ops (~50 LOC emit.zig) - Accept: Lane extract/insert operations work
