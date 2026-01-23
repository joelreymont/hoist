---
title: Port regalloc2 liveness
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:50:49.959606+02:00\""
closed-at: "2026-01-26T08:52:58.085714+01:00"
---

In src/regalloc/regalloc2.zig, add liveness analysis: compute live ranges, build interference graph. Deps: Port regalloc2 data structures. Verify: zig build test
