---
title: IR atomics
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-02T23:54:33.014335+01:00\\\"\""
closed-at: "2026-02-03T10:52:36.728762+01:00"
close-reason: Declared atomic IR terms in ir_prelude.isle
blocks:
  - hoist-ir-vector-ops-fd76c1f6
---

File: src/dsl/isle/ir_prelude.isle:1; cause: atomic_load/store/rmw terms undeclared; fix: add atomic term decls and AtomicOrdering/AtomicRmwOp enums; why: lower patterns use atomics.
