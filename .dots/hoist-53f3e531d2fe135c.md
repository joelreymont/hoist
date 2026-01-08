---
title: edit
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T06:45:42.179909+02:00"
---

File: tests/e2e_jit.zig - Memory corruption after ctx.compileFunction(). FINDINGS: (1) Fixed relocation name leaks in MachBuffer/CompiledCode. (2) With testing.allocator: panic in debug_allocator.zig:806 (bucket metadata corrupt). (3) With GPA: SIGBUS (signal 10) - suggests misaligned/invalid memory access. (4) ABI test with hand-written code PASSES, so JIT exec works. (5) MachBuffer bounds checks passed. HYPOTHESIS: Generated code may have wrong stack frame size or register corruption. NEXT: Disassemble generated code, compare to expected, check stack alignment.
