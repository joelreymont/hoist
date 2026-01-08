---
title: Build interference from liveness
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T21:20:54.221733+02:00"
---

File: src/regalloc/interference.zig. Add buildInterference(live_ranges) method. For each pair of vregs, if overlaps(), add edge to both BitSets. O(n²) but n is small for trivial allocator. ~15 min.
