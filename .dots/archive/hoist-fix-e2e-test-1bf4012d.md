---
title: Fix e2e test failures
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-23T22:25:02.202671+02:00\""
closed-at: "2026-01-23T22:35:19.699109+02:00"
---

tests/e2e_branches.zig:340, src/codegen/compile.zig:4657,1241. Cause: br_table const phi assumes all branches have args (fails on 0-arg blocks). brz block_map.get returns null (block_index_map pre-filled but destination not found). Fix: (1) skip 0-arg branches in const phi, (2) debug why block_map missing brz target.
