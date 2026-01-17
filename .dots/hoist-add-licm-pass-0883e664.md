---
title: Add LICM pass
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:52:57.776904+02:00"
---

In src/codegen/optimize.zig:168, resolve CFG type reconciliation. Implement loop-invariant code motion. Deps: Wire alias queries. Verify: zig build test
