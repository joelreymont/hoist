---
title: Out-stack lazy compute
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-21T19:21:15.550605+01:00\\\"\""
closed-at: "2026-02-21T19:39:46.048272+01:00"
close-reason: "discarded: repeat-9 gate regressions vs parent"
blocks:
  - hoist-lower-call-tmp-f0e53136
---

Context: src/codegen/compile.zig:1585-1643; cause: unconditional prepass over IR for out_stack_max; fix: lazy zero-fastpath and opportunistic updates during lowering; deps:hoist-lower-call-tmp-f0e53136; verification: tests + repeat-9 gate.
