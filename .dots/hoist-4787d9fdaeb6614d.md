---
title: Implement valid_ldr_shift extractor
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T05:51:03.702210+02:00"
closed-at: "2026-01-04T05:53:01.699955+02:00"
---

File: src/backends/aarch64/isle_helpers.zig - Add extractor that validates load register-shifted addressing mode shift amount. For AArch64 LDR with register offset, shift must match access size: I8=0, I16=1, I32=2, I64=3 (log2 of bytes). Returns shift amount if valid for type, null otherwise. Signature: pub fn valid_ldr_shift(ty: Type, shift: u8) ?u8
