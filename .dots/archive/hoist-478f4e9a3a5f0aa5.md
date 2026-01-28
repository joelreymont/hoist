---
title: Fix Layout.lastInst API call
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T14:44:44.889706+02:00"
closed-at: "2026-01-04T14:49:09.001727+02:00"
---

File: src/ir/verifier.zig:438 - Error: no field or member function named 'lastInst' in 'ir.layout.Layout'. Layout API changed, need to find replacement method to get last instruction in a block.
