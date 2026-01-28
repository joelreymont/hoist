---
title: Implement valid_str_imm_offset extractor
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T05:50:58.598021+02:00"
closed-at: "2026-01-04T05:53:01.696036+02:00"
---

File: src/backends/aarch64/isle_helpers.zig - Add extractor that validates store immediate offset fits AArch64 STR constraints (same rules as LDR). For I8: unscaled -256 to 255, I16: 0-8190 (even), I32: 0-16380 (div by 4), I64: 0-32760 (div by 8). Returns offset if valid, null otherwise. Signature: pub fn valid_str_imm_offset(ty: Type, offset: i64) ?i64
