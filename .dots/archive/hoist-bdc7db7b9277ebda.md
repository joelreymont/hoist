---
title: Integrate e-graph into optimize pipeline
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T07:46:07.359373+02:00\""
closed-at: "2026-01-09T13:18:26.589057+02:00"
---

Wire EGraphOptimizer into src/codegen/compile.zig:193 (replace TODO). Run after alias analysis, before final alias resolution. Add enable flag for opt-level control. Files: src/codegen/compile.zig:193-220. ~30 min.
