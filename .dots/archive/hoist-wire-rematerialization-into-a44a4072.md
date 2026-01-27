---
title: Wire rematerialization into linear_scan
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-27T20:13:37.916439+01:00\""
closed-at: "2026-01-27T20:41:06.978154+01:00"
---

File: src/regalloc/linear_scan.zig
Import remat.zig, call RematAnalysis.analyze() before allocation.
In spill decision: check if value is rematerializable (cost < spill cost).
If remat: emit remat instructions instead of reload.
~25 min task.
