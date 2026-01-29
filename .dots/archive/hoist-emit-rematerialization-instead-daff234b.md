---
title: Emit rematerialization instead of reload for constants
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T08:33:35.332149+01:00\""
closed-at: "2026-01-29T08:58:43.978805+01:00"
---

At reload point, re-emit constant instead of stack load.
- File: src/codegen/compile.zig:610-616
- When: spilled vreg has VRegOrigin with iconst/f32const/f64const
- Instead of: appendSpillLoad from stack
- Emit: mov_imm with original constant value
- Depends: hoist-pass-vreg-origins-ce161075, hoist-add-ischeaptorematerialize-2ff1f963
- Verify: Test function with many constants that spill
