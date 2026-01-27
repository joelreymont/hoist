---
title: Verify landing_pad usage in CFG
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-27T20:15:01.089969+01:00\""
closed-at: "2026-01-27T20:18:37.002907+01:00"
---

File: src/ir/flowgraph.zig, src/ir/cfg.zig
BlockData.is_landing_pad exists. Verify:
1. Landing pads are set when creating try_call exception successors
2. CFG validation checks landing pad reachability
3. Add test: create try_call, verify exception_successor.is_landing_pad = true
~15 min task.
