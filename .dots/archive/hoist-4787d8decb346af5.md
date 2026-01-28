---
title: Implement valid_shift_imm extractor
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T05:50:44.900670+02:00"
closed-at: "2026-01-04T05:53:01.684992+02:00"
---

File: src/backends/aarch64/isle_helpers.zig - Add extractor that validates shift immediate is valid for AArch64 (0 to bitwidth-1). For 32-bit: 0-31, for 64-bit: 0-63. Returns the value if valid, null otherwise. Used in ISLE shift/rotate rules. Signature: pub fn valid_shift_imm(ty: Type, val: u64) ?u64
