---
title: Fix Tailcall ABI
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.382785+01:00\""
closed-at: "2026-01-31T21:14:38.137698+01:00"
---

Context: src/machinst/tailcall.zig:178; cause: arg moves can clobber and stack args unsupported; fix: ordered moves + cycle breaks + stack args in AArch64; deps: hoist-plan-review-fixes-af4c6e65; verification: e2e_tail_calls + aarch64_stack_args
