---
title: Out-stack lazy compute
status: open
priority: 2
issue-type: task
created-at: "2026-02-21T19:21:15.550605+01:00"
blocks:
  - hoist-lower-call-tmp-f0e53136
---

Context: src/codegen/compile.zig:1585-1643; cause: unconditional prepass over IR for out_stack_max; fix: lazy zero-fastpath and opportunistic updates during lowering; deps:hoist-lower-call-tmp-f0e53136; verification: tests + repeat-9 gate.
