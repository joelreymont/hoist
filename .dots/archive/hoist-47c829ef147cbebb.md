---
title: P3 is now critical path - all tests blocked
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T10:34:42.829447+02:00"
closed-at: "2026-01-07T10:35:24.338339+02:00"
---

Discovery: allocateRegisters(), insertPrologueEpilogue(), and emit() in src/codegen/compile.zig are all TODO stubs that do nothing. This means:

1. No register allocation happens (VRegs stay as VRegs)
2. No prologue/epilogue is inserted (no stack frame setup)
3. No machine code is emitted (buffer stays empty)

Result: Tests fail because compileFunction() returns empty code.

The P2 opcode lowering work we've been doing (99% complete) is correct but untestable until P3 is implemented.

Action: Shift focus to P3 implementation before completing remaining P2 opcodes (call, global_value).

Files to implement:
- src/codegen/compile.zig: Wire up allocateRegisters/insertPrologueEpilogue/emit
- src/machinst/regalloc.zig: Complete LinearScanAllocator or add regalloc2 FFI
- src/backends/aarch64/abi.zig: Frame layout and prologue/epilogue generation
- src/backends/aarch64/emit.zig: Instruction encoding (mostly complete, needs integration)

Priority: CRITICAL - Nothing works until this is done
