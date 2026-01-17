---
title: Wire alias queries
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:52:47.824686+02:00"
---

In alias_analysis.zig, implement alias() query method. Return no_alias/may_alias/must_alias. Deps: Add points-to analysis. Verify: zig build test
