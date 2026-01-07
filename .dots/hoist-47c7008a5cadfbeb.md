---
title: Lower fadd, fsub, fmul, fdiv
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:11:33.395643+02:00"
closed-at: "2026-01-07T10:15:08.415933+02:00"
---

File: src/generated/aarch64_lower_generated.zig add patterns
Opcodes: fadd, fsub, fmul, fdiv
Implementation (~25 lines each): Get operands (float regs), allocate destination (float reg), emit fadd/fsub/fmul/fdiv instruction, handle F32 vs F64 sizes
Dependencies: None
Estimated: 1 day
Test: Test each operation
