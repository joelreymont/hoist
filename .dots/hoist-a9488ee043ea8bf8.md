---
title: Extract optimized IR from e-graph
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T07:46:07.354575+02:00"
---

Implement extraction: find cheapest equivalent expression, convert e-graph back to IR. Cost model based on instruction count. Files: src/ir/egraph.zig:600-750 (new). ~120 min.
