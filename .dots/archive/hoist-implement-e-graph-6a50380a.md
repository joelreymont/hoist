---
title: Implement e-graph cost model
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:51:06.374865+02:00\""
closed-at: "2026-01-25T15:40:45.371997+02:00"
---

In src/ir/egraph.zig, implement cost model for instruction selection. Consider latency, code size. Deps: Port e-graph extraction struct. Verify: zig build test
