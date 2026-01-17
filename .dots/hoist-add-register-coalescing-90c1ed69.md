---
title: Add register coalescing
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T15:05:47.564553+02:00"
---

Files: src/regalloc/trivial.zig or regalloc2 port
What: Eliminate moves between registers with non-overlapping live ranges
Algorithm: Build interference graph, coalesce non-interfering copies
Deps: hoist-port-regalloc2-coloring-24fcac51
Verification: Reduced MOV count in output
