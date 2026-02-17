---
title: Reuse lowering state
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T11:42:00.937882+01:00"
---

Persist/recycle lowering auxiliary state across compiles where correctness permits. files: src/codegen/context.zig, src/backends/aarch64/lower.zig, src/machinst/lower.zig. Cause: repeated state construction and map allocations. Fix: context-owned reusable state with deterministic reset. Why: lower constant-factor compile cost.
