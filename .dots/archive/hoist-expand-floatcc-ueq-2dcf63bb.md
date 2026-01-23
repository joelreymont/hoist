---
title: Expand FloatCC.ueq
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:51:42.180270+02:00\""
closed-at: "2026-01-23T09:54:36.492835+02:00"
---

In src/backends/aarch64/legalize.zig:56, implement multi-instruction expansion for unordered-or-equal. Use FCMP + B.VS + B.EQ pattern. Deps: none. Verify: zig build test
