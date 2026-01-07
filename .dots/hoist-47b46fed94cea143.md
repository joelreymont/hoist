---
title: Implement spill heuristic
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:02:37.790425+02:00"
closed-at: "2026-01-06T22:43:07.475806+02:00"
---

File: src/regalloc/spilling.zig - Implement chooseSpillCandidate(active_intervals, current_inst) -> LiveRange. Heuristic: choose interval with furthest next use (greedy). Simple: max(range.end_inst - current_inst). Returns the range to evict. Dependencies: hoist-47b46f8915faa497.
