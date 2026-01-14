---
title: Wire range opts
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.781998+02:00"
---

Files: src/codegen/compile.zig:700-725, src/codegen/opts/range_opts.zig:1-60
Root cause: RangeOptimizer not called in pipeline.
Fix: run RangeAnalysis + RangeOptimizer at opt_level >= basic.
Why: value-range parity with Cranelift.
Deps: none.
Verify: range opt tests.
