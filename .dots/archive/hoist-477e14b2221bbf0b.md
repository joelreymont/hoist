---
title: Add ~x + 1 = -x simplification
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T18:11:38.933797+02:00"
closed-at: "2026-01-03T18:14:19.997524+02:00"
---

File: src/codegen/opts/instcombine.zig - Add pattern in combineBinary: if iadd with bnot(x) and const 1, replace with ineg(x). Requires detecting bnot unary operation.
