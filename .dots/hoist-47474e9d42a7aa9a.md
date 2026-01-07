---
title: Generate x64 lowering from ISLE
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-01T00:50:47.443122+02:00\""
closed-at: "\"2026-01-01T06:43:45.392987+02:00\""
close-reason: ISLE→Zig codegen integrated into compiler. Built islec with --target zig flag. X64 lowering requires full ISLE dependency chain (inst.isle + prelude).
blocks:
  - hoist-47474ddc4f78c918
---

Run retargeted ISLE on ../wasmtime/cranelift/codegen/src/isa/x64/lower.isle (5k LOC rules). More complex than aarch64. Includes memory operand folding, LEA optimization.
