---
title: Fix remaining IR test errors
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T15:16:28.077006+02:00"
closed-at: "2026-01-04T15:19:23.444805+02:00"
---

Files: src/ir/domtree.zig:933, jump_table_data.zig:91,115,136 (deinit allocator), loops.zig:135, ssa_tests.zig multiple (getOrDefault removed, deinit allocator). Need to fix argument count mismatches.
