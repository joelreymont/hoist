---
title: Fix loops.zig CFG iteration
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T13:20:36.472562+02:00"
closed-at: "2026-01-05T13:24:13.775784+02:00"
---

File: src/ir/loops.zig:99 - Code is trying to access cfg.succs.iterator() which doesn't exist. Need to iterate over all blocks in CFG and their successors. Should use a block iterator or range to iterate through all blocks, then use cfg.successors(block) for each.
