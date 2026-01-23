---
title: Add phi pruning to SSA builder
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:50:58.773095+02:00\""
closed-at: "2026-01-25T15:38:51.915669+02:00"
---

In src/ir/ssa_builder.zig, implement phi pruning to remove trivial phis. Deps: Add phi insertion to SSA builder. Verify: zig build test
