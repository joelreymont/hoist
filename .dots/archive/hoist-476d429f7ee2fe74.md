---
title: "Implement LowerCtx - Create src/machinst/lower_ctx.zig - Define LowerCtx wrapping VCodeBuilder, VRegAllocator, DFG. Add helpers for value lookup, type query, constant materialization, block/label management, ABI context. ~200 lines. Cranelift ref: machinst/lower.rs:Lower. Test: Unit test lowering simple IR instruction. Commit: Implement lowering context (LowerCtx)"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-02T22:07:35.019697+02:00"
closed-at: "2026-01-02T22:43:49.533677+02:00"
close-reason: Completed via TodoWrite
---

Implementing LowerCtx
