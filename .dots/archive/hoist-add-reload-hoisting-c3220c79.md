---
title: Add reload hoisting analysis
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-27T20:14:41.080261+01:00\""
closed-at: "2026-01-27T20:41:06.985500+01:00"
---

File: src/regalloc/linear_scan.zig or new hoist.zig
Find reloads inside loops that could move to loop preheader.
Requires: loop detection (dominator tree), reload point tracking.
Pattern: if reload dominates all uses and loop contains reload, hoist.
~30 min for analysis structure, more for full impl.
