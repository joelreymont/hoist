---
title: Fix Egraph Const Predicates
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T10:05:45.373194+01:00\\\"\""
closed-at: "2026-01-29T10:24:34.258944+01:00"
close-reason: done
---

Context: src/ir/egraph.zig:684; cause: iconst treated as zero, one never detected; fix: use const payload for zero/one checks; deps: hoist-update-enode-const-f565d6d5; verification: egraph rule tests updated
