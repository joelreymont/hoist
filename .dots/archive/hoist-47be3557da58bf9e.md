---
title: Implement spill heuristic
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T22:42:04.572282+02:00"
closed-at: "2026-01-06T22:51:14.433119+02:00"
---

File: src/regalloc/linear_scan.zig - When tryAllocateReg returns null (out of registers), need to choose which active interval to spill. Add spillInterval() method that: 1) Finds active interval with furthest next use, 2) Removes it from active list, 3) Frees its register, 4) Returns the freed register for current interval. For now, next-use can be approximated as end_inst
