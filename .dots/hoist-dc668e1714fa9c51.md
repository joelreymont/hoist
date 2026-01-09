---
title: Implement range propagation dataflow
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T07:46:07.378415+02:00"
---

Build dataflow pass to propagate ranges through IR: handle arithmetic, comparisons, phi nodes, widening at loop headers. Files: src/ir/value_range.zig:250-500 (new). ~180 min.
