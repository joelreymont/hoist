---
title: Fix LoopInfo.clear missing method
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T14:49:15.481849+02:00"
closed-at: "2026-01-04T15:04:23.232559+02:00"
---

File: src/codegen/context.zig:81 - Error: no field or member function named 'clear' in 'ir.loops.LoopInfo'. Need to check if LoopInfo has clear() method or comment it out like domtree.clear().
