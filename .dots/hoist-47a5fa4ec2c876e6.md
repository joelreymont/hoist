---
title: Implement ABI parameter passing for AArch64
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T17:47:34.905557+02:00"
closed-at: "2026-01-05T18:17:02.047348+02:00"
---

File: tests/e2e_jit.zig:294 - Multiply test fails because function parameters aren't passed correctly. Block parameters need to be mapped to ABI registers (x0, x1, x2, etc. for integer args on AArch64). Need to implement parameter lowering in compile pipeline: when entering a function, map first N block params of entry block to physical registers according to calling convention. See Cranelift's ABICallerImpl for reference. Depends on prologue/epilogue work.
