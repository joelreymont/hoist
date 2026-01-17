---
title: Add F16 soft-float ops
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:40.928634+02:00"
---

In src/codegen/legalize_ops.zig:146-149, implement F16 soft-float operations. Call libm for add/sub/mul/div. Deps: none. Verify: zig build test
