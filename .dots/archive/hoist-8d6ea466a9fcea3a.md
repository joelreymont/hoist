---
title: edit
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T06:11:18.172180+02:00\""
closed-at: "2026-01-08T06:15:13.860270+02:00"
---

File: tests/e2e_jit.zig - CRITICAL allocator corruption during compilation.

STATUS: Reproduced consistently - this is a REAL memory corruption bug in the compilation pipeline.

CONFIRMED EVIDENCE:
- JIT code executes CORRECTLY and returns 42 ✓
- Machine code is PERFECT (20 bytes) ✓
- Use-after-free in test code FIXED ✓
- Corruption happens DURING ctx.compileFunction(), not after
- Debug prints show: 'Compiling function...' → 'Compilation complete' → CRASH
- Next attempted allocation (for debug print or allocExecutableMemory) triggers 'reached unreachable code'
- Crash is in debug_allocator.zig:806 trying to set log2PtrAligns[slot_count]
- Stack shows ___gtxf2 (long double comparison) - allocator internals

ROOT CAUSE:
Memory corruption occurs DURING compilation pipeline. The corruption is latent until next allocation attempt.

CRITICAL FIX NEEDED:
This blocks ALL JIT tests. Must fix before any JIT functionality can be tested.

RECOMMENDED APPROACH:
1. Run with AddressSanitizer: zig build test -Doptimize=Debug -fsanitize=address
2. Use GeneralPurposeAllocator with safety checks instead of testing.allocator
3. Add assertions in MachBuffer.put4/putSlice to detect buffer overruns
4. Check CompiledCode.deinit() for double-free
5. Audit ArrayList usage in compile.zig for unmanaged → managed migration issues (Zig 0.15)

Files to audit:
- src/machinst/buffer.zig (MachBuffer)
- src/codegen/compile.zig (compilation pipeline)  
- src/codegen/context.zig (CompiledCode ownership)
- src/backends/aarch64/emit.zig (instruction emission)
