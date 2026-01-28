---
title: "analysis: verifier"
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-01T11:02:25.612447+02:00\""
closed-at: "\"2026-01-01T17:09:31.557821+02:00\""
close-reason: "\"completed: src/ir/verifier.zig with IR verification (structure validation, SSA use-before-def checking, type consistency, control flow validation). Collects error messages for debugging. All tests pass.\""
blocks:
  - hoist-474fd9fed2eab9f6
---

src/verifier.zig (~2k LOC)

Port from: cranelift/codegen/src/verifier/*.rs

IR verification passes:

SSA validity:
- Every use dominated by its def
- No uses of undefined values
- Block params match predecessor args

Type checking:
- Instruction operand types match
- Return types match signature

CFG validity:
- Entry block has no predecessors
- Terminators only at block end
- All blocks reachable

Instruction-specific:
- Branch targets exist
- Call signatures match
- Memory alignments valid

Run after every transform in debug mode
