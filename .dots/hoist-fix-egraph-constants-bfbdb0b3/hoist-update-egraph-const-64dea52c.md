---
title: Update Egraph Const Tests
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T10:05:45.378061+01:00\\\"\""
closed-at: "2026-01-29T10:25:27.054392+01:00"
close-reason: done
---

Context: src/ir/egraph.zig:880; cause: tests create value-less iconst; fix: create const nodes with explicit values and add checks; deps: hoist-fix-egraph-const-5999d024; verification: zig test src/ir/egraph.zig
