---
title: Liveness-based spilling
status: open
priority: 2
issue-type: task
created-at: "2026-01-07T15:24:08.010295+02:00"
---

Implement spilling heuristic (furthest next use). Insert spills/reloads at appropriate points. Handle spill cascades (spilling may create new vregs). Update liveness after insertion. Test: Spill in program with >30 live values. Phase 1.10, Priority P0
