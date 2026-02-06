---
title: Resolve inliner callees
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"\\\\\\\"2026-02-02T21:35:56.926790+01:00\\\\\\\"\\\"\""
closed-at: "2026-02-06T10:10:49.700854+01:00"
close-reason: Implemented metadata-based callee resolution and tests
blocks:
  - hoist-implement-partial-loop-2c8a074d
---

Context: src/codegen/opts/inliner.zig:292; cause: callee resolution TODO; fix: map call instruction to callee func and inline when eligible; deps: call graph access; verification: add inliner tests + zig build test
