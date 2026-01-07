---
title: Check coalescing safety
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:07:12.396779+02:00"
closed-at: "2026-01-07T06:30:37.705790+02:00"
---

File: src/regalloc/coalescing.zig - Implement canCoalesce(src, dst, interference_graph) -> bool. Check: \!interference_graph.interferes(src, dst). If they don't interfere, can share physical reg. This is the Briggs conservative coalescing criterion. Dependencies: hoist-47b47fcb8bc68837, hoist-47b478cbd9522fe0.
