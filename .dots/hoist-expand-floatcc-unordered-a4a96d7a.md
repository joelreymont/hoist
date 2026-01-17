---
title: Expand FloatCC unordered variants
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:51:42.191613+02:00"
---

In src/backends/aarch64/legalize.zig:58-61, implement ult/ule/ugt/uge expansions. Each needs VS check + ordered compare. Deps: Expand FloatCC.one. Verify: zig build test
