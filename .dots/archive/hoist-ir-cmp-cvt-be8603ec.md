---
title: IR cmp/cvt
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-02T23:54:20.014089+01:00\\\"\""
closed-at: "2026-02-03T10:21:11.631559+01:00"
close-reason: Declared IR cmp/cvt terms
blocks:
  - hoist-ir-float-ops-7621291d
---

File: src/dsl/isle/ir_prelude.isle:1; cause: icmp/fcmp and fcvt/bitcast terms undeclared; fix: add cmp/cvt term decls with extern ctor/extractor and CC enums; why: comparisons and conversions are required for lowering.
