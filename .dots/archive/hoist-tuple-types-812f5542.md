---
title: Tuple types
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T20:49:04.122222+01:00\""
closed-at: "2026-01-29T20:53:08.143783+01:00"
close-reason: completed
---

Full context: src/dsl/isle/sema.zig:571 errors on multi-return decls (e.g., multi_lane). Cause: no tuple type support. Fix: add tuple Type variant and map decl ret_tys>1 to tuple types; update codegen/type-name helpers. Why: support multi-output extractors.
