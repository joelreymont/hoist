---
title: Add ISLE coverage for load/store ops
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-27T20:12:44.595333+01:00\""
closed-at: "2026-01-27T20:20:06.762597+01:00"
---

File: tests/isle_memory.zig
Add tests for: load, store with different types (i8, i16, i32, i64).
Check isle_coverage tracks memory access rules.
Verify addressing modes are covered (reg+offset, reg+reg).
~20 min task.
