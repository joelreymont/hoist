---
title: Wire coalescing into linear_scan
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-27T20:13:29.482429+01:00\""
closed-at: "2026-01-27T20:40:10.806850+01:00"
---

File: src/regalloc/linear_scan.zig
Import coalesce.zig, call CoalesceAnalysis.analyze() before allocation.
Apply coalesced registers: merge live ranges, update vreg mappings.
Check interference graph before coalescing.
~25 min task.
