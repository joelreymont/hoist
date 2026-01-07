---
title: Implement buildInterferenceGraph function
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:26:29.884766+02:00"
closed-at: "2026-01-07T06:29:44.992996+02:00"
---

File: src/regalloc/interference.zig - Add pub fn buildInterferenceGraph(allocator: Allocator, liveness: *LivenessInfo) !InterferenceGraph. Algorithm: 1) Create graph with liveness.ranges.items.len vregs, 2) Double loop over all LiveRange pairs, 3) For each pair where ranges overlap, call graph.addEdge(r1.vreg, r2.vreg). O(N²) complexity but N typically <100. Returns populated InterferenceGraph. Critical for graph coloring allocator.
