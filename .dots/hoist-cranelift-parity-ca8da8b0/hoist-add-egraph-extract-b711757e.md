---
title: Add egraph extract
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.770695+02:00"
---

Files: src/codegen/compile.zig:758-800, docs/egraph-design.md:146-154
Root cause: egraph pass never extracts optimized IR.
Fix: implement extraction and rebuild IR from egraph.
Why: enable egraph optimizations.
Deps: none.
Verify: egraph optimization tests.
