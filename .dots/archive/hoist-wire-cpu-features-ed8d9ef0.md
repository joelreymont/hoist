---
title: Wire CPU features to codegen
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:53:49.604975+02:00\""
closed-at: "2026-01-26T08:58:12.172342+01:00"
---

In src/backends/aarch64, use detected features to enable/disable instructions. Deps: Add runtime CPU detection. Verify: zig build test
