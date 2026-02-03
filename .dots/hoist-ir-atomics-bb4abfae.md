---
title: IR atomics
status: open
priority: 1
issue-type: task
created-at: "2026-02-02T23:54:33.014335+01:00"
blocks:
  - hoist-ir-vector-ops-fd76c1f6
---

File: src/dsl/isle/ir_prelude.isle:1; cause: atomic_load/store/rmw terms undeclared; fix: add atomic term decls and AtomicOrdering/AtomicRmwOp enums; why: lower patterns use atomics.
