---
title: Fix A64 sigs
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-02T23:54:56.206796+01:00\""
closed-at: "2026-02-03T11:45:22.967331+01:00"
close-reason: Make typed IR ops explicit
blocks:
  - hoist-decl-lower-d98b4ce5
---

File: src/backends/aarch64/lower.isle:200-600; cause: IR op arity/type mismatches vs decls (iadd/isub/imul/etc); fix: align patterns with IR op signatures; why: ISLE typecheck/codegen.
