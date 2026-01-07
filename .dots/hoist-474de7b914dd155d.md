---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:43:05.984231+02:00"
closed-at: "2026-01-01T09:05:17.928263+02:00"
close-reason: Replaced with correctly titled task
---

Port instruction opcodes from cranelift/codegen/src/ir/instructions.rs (~2500 LOC + generated). Create src/ir/instructions.zig with Opcode enum, InstructionData variants, instruction formats. Depends on: entities (hoist-474de7656791a5b2), types (hoist-474de713105101e3). Files: src/ir/instructions.zig, opcodes.zig. Core IR operations (iadd, imul, load, store, br, call, etc.).
