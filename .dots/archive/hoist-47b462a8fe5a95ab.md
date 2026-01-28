---
title: Wire frame layout to compile pipeline
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:58:55.191652+02:00"
closed-at: "2026-01-06T21:17:38.646197+02:00"
---

File: src/codegen/compile.zig - Call computeFrameLayout before lowering. Store layout in context. Call emitPrologue at function start (before first basic block). Call emitEpilogue before each RET instruction. Dependencies: hoist-47b4625c4e194ee1.
