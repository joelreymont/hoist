---
title: Implement interference graph construction
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:39.157239+02:00"
closed-at: "2026-01-06T11:04:59.274282+02:00"
---

File: src/regalloc/interference.zig. Build graph: nodes = SSA values, edges = values with overlapping live ranges (interfere, cannot share register). Use liveness intervals from existing liveness dot. Output: adjacency list or matrix. Dependencies: liveness analysis (existing dot). Effort: 2-3 days.
