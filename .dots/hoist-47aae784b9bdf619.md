---
title: Implement direct call lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T23:40:14.511557+02:00"
closed-at: "2026-01-05T23:41:55.450697+02:00"
---

File: src/codegen/compile.zig. Opcode: call. Instruction: call (pseudo) → BL. Maps IR call to ARM64 BL instruction with function reference. CallData contains func_ref and args. Effort: 1 hour.
