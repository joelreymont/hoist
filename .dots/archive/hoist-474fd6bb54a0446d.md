---
title: "x64: ABI"
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-01T11:01:30.853547+02:00\""
closed-at: "\"2026-01-01T16:51:26.344831+02:00\""
close-reason: "\"completed: src/backends/x64/abi.zig with System-V and Windows Fastcall calling conventions, prologue/epilogue generation, callee-save handling. All tests pass.\""
blocks:
  - hoist-474fd6bb31d63f3f
---

src/backends/x64/abi.zig (~800 LOC)

Port from: cranelift/codegen/src/isa/x64/abi.rs

Two calling conventions:

System V AMD64 (Linux, macOS):
- Args: RDI, RSI, RDX, RCX, R8, R9, then stack
- Returns: RAX (+ RDX for wide)
- Caller-saved: RAX, RCX, RDX, RSI, RDI, R8-R11
- Callee-saved: RBX, RBP, R12-R15
- Red zone: 128 bytes below RSP

Windows x64:
- Args: RCX, RDX, R8, R9, then stack
- Shadow space: 32 bytes always reserved
- Returns: RAX
- Different callee-saved set

Frame layout:
- Push RBP / mov RBP, RSP (optional)
- Sub RSP for locals
- Align to 16 bytes before calls
