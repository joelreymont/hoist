---
title: Wire Codegen Pipeline
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-02T21:35:56.552154+01:00\\\"\""
closed-at: "2026-02-06T18:59:49.938950+01:00"
close-reason: Wired compile/lower/regalloc/rewrite/emit with tests.
blocks:
  - hoist-add-bench-baseline-9f13b2d1
---

Context: src/codegen/compile.zig:5008; cause: lowering/regalloc/emit stubs; fix: wire full pipeline; deps: Plan: Review Fixes; verification: compile_simple + e2e
