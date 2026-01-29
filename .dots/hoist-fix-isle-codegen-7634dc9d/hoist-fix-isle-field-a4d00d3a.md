---
title: Fix ISLE Field Pattern Recursion
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.502384+01:00"
---

Context: src/dsl/isle/codegen/match.zig:310; cause: field patterns not compiled; fix: recursively compile field patterns and add constraints; deps: hoist-fix-isle-codegen-7634dc9d; verification: isle matcher tests
