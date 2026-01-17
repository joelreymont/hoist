---
title: Wire CPU features to codegen
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:49.604975+02:00"
---

In src/backends/aarch64, use detected features to enable/disable instructions. Deps: Add runtime CPU detection. Verify: zig build test
