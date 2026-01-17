---
title: Add phi insertion to SSA builder
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:50:58.767724+02:00"
---

In src/ir/ssa_builder.zig, implement phi insertion algorithm. Place phis at dominance frontiers. Deps: Add SSA builder struct. Verify: zig build test
