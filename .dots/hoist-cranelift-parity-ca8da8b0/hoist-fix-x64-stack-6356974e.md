---
title: Fix x64 stack
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.588722+02:00"
---

Files: src/backends/x64/abi.zig:138-168
Root cause: prologue/epilogue uses add/sub reg instead of imm stack adjust.
Fix: add sub/add imm encodings and use them for frame alloc/free.
Why: correct ABI and stack size handling.
Deps: Add x64 alu, Emit x64 alu.
Verify: x64 ABI prologue tests.
