---
title: Fix Egraph Const Predicates
status: active
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.373194+01:00\""
---

Context: src/ir/egraph.zig:684; cause: iconst treated as zero, one never detected; fix: use const payload for zero/one checks; deps: hoist-update-enode-const-f565d6d5; verification: egraph rule tests updated
