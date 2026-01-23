---
title: Wire dyn_scale_target_const
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:53:22.354780+02:00\""
closed-at: "2026-01-23T23:59:37.850873+02:00"
---

In src/backends/aarch64/isle_impl.zig:1428, implement dyn_scale_target_const. Query runtime vector length. Deps: Add SVE basic ops. Verify: zig build test
