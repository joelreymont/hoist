---
title: Add try_call builder method
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T21:19:10.665234+02:00"
---

File: src/ir/builder.zig. Add instTryCall(callee, args, normal_block, exception_block) method. Creates try_call instruction, wires both successors to CFG. Returns call result value. ~15 min.
