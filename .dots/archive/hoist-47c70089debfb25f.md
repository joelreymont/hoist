---
title: Lower ishl_imm, ushr_imm, sshr_imm
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:11:33.363402+02:00"
closed-at: "2026-01-07T10:00:09.314070+02:00"
---

File: src/generated/aarch64_lower_generated.zig add patterns
Opcodes: ishl_imm, ushr_imm, sshr_imm
Implementation (~20 lines each): Get operands (reg + shift amount), emit lsl_imm/lsr_imm/asr_imm instruction
Dependencies: None
Estimated: 4 hours
Test: Test shifts by constant
