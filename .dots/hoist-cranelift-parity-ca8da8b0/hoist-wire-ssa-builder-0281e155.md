---
title: Wire ssa builder
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.706249+02:00"
---

Files: src/ir/builder.zig:1-120
Root cause: FunctionBuilder lacks SSA helper APIs.
Fix: embed SSA builder or expose helpers on FunctionBuilder.
Why: ergonomic frontend parity.
Deps: Add ssa builder.
Verify: builder integration tests.
