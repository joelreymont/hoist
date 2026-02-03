---
title: Decl lower
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-02T23:54:52.988915+01:00\\\"\""
closed-at: "2026-02-03T11:19:42.743776+01:00"
close-reason: Declared lower entry point in backend ISLE files
blocks:
  - hoist-rv-decls-4c9f7668
---

File: src/backends/*/lower.isle:1; cause: lower term not declared in backend ISLE files; fix: add decl lower with backend inst type; why: entry point required for generated lowering.
