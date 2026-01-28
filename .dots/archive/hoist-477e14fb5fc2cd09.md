---
title: Add ~(x - 1) = -x simplification
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T18:11:43.733709+02:00"
closed-at: "2026-01-03T18:15:08.466911+02:00"
---

File: src/codegen/opts/instcombine.zig - Add pattern in combineUnary for bnot: if arg is isub(x, 1), replace with ineg(x). Requires detecting isub with const 1.
