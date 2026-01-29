---
title: AST extern kind
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T20:16:03.367195+01:00"
---

Full context: src/dsl/isle/ast.zig:84 ExternDef lacks kind (constructor/extractor). Cause: extern syntax not represented. Fix: add kind enum and parse it. Why: sema/codegen need extern mapping.
