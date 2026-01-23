---
title: Add imm12 extractors
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:04:55.249609+02:00\""
closed-at: "2026-01-24T00:25:11.663920+02:00"
---

Files: src/backends/aarch64/isle_impl.zig
What: Add imm12_from_value and imm12_from_negated_value extractors
Purpose: Fold constants into ADD/SUB immediate operands
Pattern: Check if value fits in 12-bit immediate (optionally shifted by 12)
Verification: Test with iadd_imm patterns
