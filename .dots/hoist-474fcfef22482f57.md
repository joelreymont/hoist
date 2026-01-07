---
title: "IR: builder"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T10:59:36.808018+02:00\""
closed-at: "\"2026-01-01T15:29:19.215626+02:00\""
close-reason: Completed FunctionBuilder with createBlock, switchToBlock, appendBlockParam, iconst, iadd, isub, imul, jump, ret, all tests passing. Can construct IR functions programmatically.
blocks:
  - hoist-474fcfef12b1d344
---

src/ir/builder.zig (~500 LOC)

Port from: cranelift/codegen/src/ir/builder.rs

FunctionBuilder - ergonomic IR construction:
- func: *Function
- position: current Block
- Tracks sealed blocks for SSA construction

Key API:
- create_block() -> Block
- switch_to_block(block)
- append_block_param(block, ty) -> Value
- ins() -> InstBuilder (chainable instruction insertion)
- seal_block(block) - mark no more predecessors
- finalize() - complete SSA construction

InstBuilder methods:
- iconst(ty, val) -> Value
- iadd(a, b) -> Value
- call(func, args) -> Inst
- jump(block, args)
- brif(cond, then_block, else_block, args)

MILESTONE: After this, can construct complete IR functions!
