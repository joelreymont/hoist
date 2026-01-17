---
title: Add F128 soft-float ops
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:40.934395+02:00"
---

In src/codegen/legalize_ops.zig:146-149, implement F128 soft-float operations. 128-bit float math via libcalls. Deps: Add F16 soft-float ops. Verify: zig build test
