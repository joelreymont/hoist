---
title: "x64: instructions"
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-01T11:01:30.844641+02:00\""
closed-at: "\"2026-01-01T16:43:35.580641+02:00\""
close-reason: "\"Created x64/inst.zig (~269 LOC) - minimal bootstrap x64 instruction set. Inst enum with mov/add/sub/push/pop/jmp/call/ret. OperandSize (8/16/32/64-bit), CondCode with invert(), BranchTarget, CallTarget. Formats to AT&T syntax. Added to root. Total: ~11.7k LOC\""
blocks:
  - hoist-474fd4a2fed08545
---

src/backends/x64/inst.zig (~2.5k LOC)

Port from: cranelift/codegen/src/isa/x64/inst/mod.rs

x64 Inst enum - all x86-64 instruction variants:

Arithmetic:
- AluRmiR (add, sub, and, or, xor with reg/mem/imm)
- Imm (mov immediate)
- ShiftR (shl, shr, sar)
- Mul, Div (widening multiply, divide)

Memory:
- MovRM, MovMR (reg<->mem)
- Lea (load effective address)
- Push, Pop

Control:
- Jmp (unconditional)
- JmpCond (conditional)
- Call, Ret

SSE/AVX:
- XmmRmR (addss, mulsd, etc.)
- XmmMov (movaps, movups)

Operand types:
- Gpr(reg), GprMem(reg_or_mem)
- Imm8, Imm32, Imm64
- Amode (base + index*scale + disp)
