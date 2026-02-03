---
title: IR helpers
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-02T23:54:37.672184+01:00\\\"\""
closed-at: "2026-02-03T11:03:21.096683+01:00"
close-reason: Added value/type helpers and immediate extractors to ir_prelude.isle
blocks:
  - hoist-ir-atomics-bb4abfae
---

File: src/dsl/isle/ir_prelude.isle:1; cause: helper terms (value_type/has_type/ty_* helpers, imm conversions) missing; fix: add helper term decls used by lower patterns; why: ISLE rules rely on these relations.
