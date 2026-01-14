---
title: Wire multi return
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.565949+02:00"
---

Files: src/backends/aarch64/isle_helpers.zig:3771-3879, src/codegen/isle_ctx.zig:88-141
Root cause: marshalReturnValues errors on >2 returns.
Fix: plumb extended ValueRegs through lowering and call return handling.
Why: multi-return parity with Cranelift.
Deps: Extend value regs.
Verify: multi-return ABI tests.
