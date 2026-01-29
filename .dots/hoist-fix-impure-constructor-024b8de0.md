---
title: Fix impure constructor instances
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T21:40:42.692981+01:00"
---

Context: src/dsl/isle/codegen/match.zig:400; cause: impure constructors all use instance=1 leading to binding dedup and incorrect side effects; fix: track per-rule instance counter and assign unique ids, add test; deps: hoist-add-partial-decl-6b17700a; verification: NO_COLOR=1 zig build test
