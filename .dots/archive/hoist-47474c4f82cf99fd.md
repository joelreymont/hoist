---
title: Port IR types (Type, Value, Inst, Block)
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T00:50:08.793304+02:00\""
closed-at: "\"2026-01-01T01:03:38.566406+02:00\""
close-reason: "\"Done: ir.zig 48 LOC\""
blocks:
  - hoist-47474a7ef00d44d0
---

Files: ../wasmtime/cranelift/codegen/src/ir/{types.rs,entities.rs,instructions.rs}. Type=u16 encoding, Value/Inst/Block=u32 entity refs. InstructionData=16-byte fixed struct. ~3k LOC.
