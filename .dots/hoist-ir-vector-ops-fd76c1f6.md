---
title: IR vector ops
status: open
priority: 1
issue-type: task
created-at: "2026-02-02T23:54:27.985818+01:00"
blocks:
  - hoist-ir-mem-ctrl-3e1d4454
---

File: src/dsl/isle/ir_prelude.isle:1; cause: vconst/extractlane/insertlane/vector types/vec ops undeclared; fix: add vector term decls and vec enums (VecALUOp/VecElemSize/VecMisc2); why: SIMD lowering needs these terms.
