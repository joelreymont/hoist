---
title: Add jump table CFG edges
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:49.595334+02:00"
---

In src/ir/flowgraph.zig:49 and cfg.zig:132, add edges to jump table destinations. Lookup from function.jump_tables. Deps: none. Verify: zig build test
