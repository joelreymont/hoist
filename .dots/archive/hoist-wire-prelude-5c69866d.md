---
title: Wire prelude
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-02T23:54:42.173504+01:00\\\"\""
closed-at: "2026-02-03T11:04:43.139017+01:00"
close-reason: Loaded ir_prelude.isle as first ISLE source
blocks:
  - hoist-ir-helpers-c147e04f
---

File: tools/isle_compiler.zig:1; cause: ISLE compiler only reads input file; fix: load ir_prelude.isle as first source before user file; why: shared IR decls must be available for lower/opts.
