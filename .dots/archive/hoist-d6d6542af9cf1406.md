---
title: Debug allocator corruption in e2e_jit test
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T00:43:16.954240+02:00"
---

File: tests/e2e_jit.zig - Test 'compile and execute return constant i32' crashes with 'reached unreachable code' in debug allocator (std/heap/debug_allocator.zig:806). Machine code generation is CORRECT (verified: 20 bytes, proper prologue/epilogue/ret). Stack trace shows recursive panic during allocator resize operation in log2PtrAligns. Root cause: likely memory corruption from code generation, buffer management, or register allocation. NOT an infinite loop. Investigation needed: check MachBuffer management, CompiledCode deinit, register allocator memory safety.
