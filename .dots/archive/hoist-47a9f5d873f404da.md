---
title: Implement register spilling strategy
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:39.912448+02:00"
closed-at: "2026-01-06T11:02:31.198724+02:00"
---

File: src/regalloc/spilling.zig. When no registers available: choose value to spill (heuristic: furthest next use, or cheapest to reload). Allocate stack slot. Insert spill store after definition, reload before each use. Update live intervals. May need to spill multiple values. Dependencies: stack slot allocation, linear scan algorithm. Effort: 3-4 days.
