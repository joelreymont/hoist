---
title: Reserve outgoing args
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-30T18:12:43.798268+01:00\""
closed-at: "2026-01-31T09:19:46.222928+01:00"
close-reason: completed
---

Context: src/codegen/compile.zig:1646, src/machinst/lower.zig:286; cause: frame size ignores outgoing stack args and stack slots overlap; fix: compute max call stack_arg_space from CallLayout, add to locals size, include in getStackSlotOffset; deps: hoist-add-call-layout-1873bf08; verification: unit test for stack offset + zig build test
