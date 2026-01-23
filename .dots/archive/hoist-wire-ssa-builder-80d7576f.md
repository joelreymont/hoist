---
title: Wire SSA builder to compile.zig
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:50:58.778100+02:00\""
closed-at: "2026-01-25T15:39:19.864894+02:00"
---

In src/codegen/compile.zig:728-738, use SSABuilder instead of stubbed removeConstantPhis(). Deps: Add phi pruning to SSA builder. Verify: zig build test
