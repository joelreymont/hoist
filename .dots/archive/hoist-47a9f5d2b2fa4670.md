---
title: Implement linear scan register allocation algorithm
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:39.535364+02:00"
closed-at: "2026-01-06T11:00:04.043956+02:00"
---

File: src/regalloc/linear_scan.zig. Linear scan: sort live intervals by start point, iterate, assign register to each interval. If no register available, spill (see spilling dot). Simpler and faster than graph coloring. Cranelift uses linear scan. Output: register assignment for each value. Dependencies: interference graph, register pressure (existing dots). Effort: 3-5 days.
