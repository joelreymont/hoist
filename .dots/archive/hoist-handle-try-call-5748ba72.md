---
title: Handle try_call in flowgraph CFG
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-27T20:14:16.455658+01:00\""
closed-at: "2026-01-27T20:17:30.578988+01:00"
---

File: src/ir/flowgraph.zig:38
Add case for .try_call and .try_call_indirect in analyzeBlock switch.
Pattern:
.try_call => |tc| {
    try cfg.addEdge(block, tc.normal_successor);
    try cfg.addEdge(block, tc.exception_successor);
},
Add test case in flowgraph.zig.
~20 min task.
