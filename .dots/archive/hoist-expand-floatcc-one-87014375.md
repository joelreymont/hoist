---
title: Expand FloatCC.one
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:51:42.186100+02:00\""
closed-at: "2026-01-23T09:54:36.498595+02:00"
---

In src/backends/aarch64/legalize.zig:57, implement ordered-not-equal expansion. Use FCMP + B.VC + B.NE pattern. Deps: Expand FloatCC.ueq. Verify: zig build test
