---
title: Implement br_table index bounds check
status: open
priority: 2
issue-type: task
created-at: "2026-01-07T22:29:21.246038+02:00"
---

File: src/backends/aarch64/isle_impl.zig:1205 - In br_table lowering, emit CMP + B.HS to check if index >= table size. If out of bounds, branch to default case. Otherwise continue to table lookup. This prevents undefined behavior from bad indices. Part of hoist-47cc378901aee993.
