---
title: Add IR print
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-01-17T12:46:36.925338+02:00\\\"\""
closed-at: "2026-01-17T13:33:38.475031+02:00"
---

Files: src/ir/print.zig (new), src/ir/function.zig (use), src/ir/instruction_data.zig:338-655. Cause: no full IR printer; Function.format is summary only. Fix: implement IR dump with blocks, params, insts, operands, immediates, results. Why: stage-level debug visibility. Verify: add snapshot test with ohsnap for a small function.
