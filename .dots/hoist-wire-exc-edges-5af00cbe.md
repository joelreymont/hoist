---
title: Wire exception edges to CFG
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:33.304412+02:00"
---

In src/ir/cfg.zig, add exception edges from try_call to landing pads. Deps: Add landing pad block type. Verify: zig build test
