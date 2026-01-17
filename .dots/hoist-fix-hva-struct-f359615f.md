---
title: Fix HVA struct class
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:51:22.406311+02:00"
---

In src/backends/aarch64/isle_helpers.zig:3179,3687, implement TODO: Handle HVA struct class. Detect vector aggregates. Deps: Fix HFA stack passing. Verify: zig build test
