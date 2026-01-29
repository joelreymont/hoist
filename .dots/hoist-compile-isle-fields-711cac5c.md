---
title: Compile ISLE fields
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T18:27:04.052062+01:00"
---

Context: src/dsl/isle/codegen/match.zig:310; cause: constructor patterns ignore field subpatterns; fix: recursively compile field patterns and emit constraints; deps: none; verification: zig build test
