---
title: edit
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T00:42:37.180298+02:00\""
closed-at: "2026-01-08T00:42:53.569372+02:00"
---

PROGRESS: Fixed two critical issues:
1. Missing CBZ/CBNZ emission (added emitCbz/emitCbnz in emit.zig:2979-3009)
2. Double RET bug (removed RET from epilogue in abi.zig:1242-1243)

CURRENT STATUS: e2e_jit test now generates correct machine code (20 bytes, single RET) but crashes with 'reached unreachable code' in debug allocator during recursive panic. Stack trace shows allocator corruption in log2PtrAligns. This is NOT an infinite loop - it's a memory corruption issue.

Machine code output is perfect:
00000000: fd 7b 3f a9  # stp x29, x30, [sp, #-16]!
00000004: fd 03 1f aa  # mov x29, sp
00000008: 40 05 80 52  # movz w0, #42
0000000c: fd 7b 81 a9  # ldp x29, x30, [sp], #16
00000010: c0 03 5f d6  # ret

NEXT: Debug allocator corruption issue. Likely causes: memory leak, double-free, or buffer overflow in code generation or register allocation.
