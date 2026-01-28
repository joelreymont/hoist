---
title: Implement buildInterferenceGraph
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:05:06.574686+02:00"
closed-at: "2026-01-07T06:26:17.299970+02:00"
---

File: src/regalloc/interference.zig - Implement buildInterferenceGraph(liveness: LivenessInfo) -> InterferenceGraph. Double loop over live ranges: for each pair (r1, r2), if rangesConflict(r1, r2), add_edge(r1.vreg, r2.vreg). O(N²) but N is small (<100 vregs typically). Dependencies: hoist-47b4785c8b399e38, hoist-47b4657292930b98.
