---
title: Compile ISLE fields
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T18:27:04.052062+01:00\""
closed-at: "2026-01-29T18:34:30.839280+01:00"
close-reason: completed
---

Context: src/dsl/isle/codegen/match.zig:310; cause: constructor patterns ignore field subpatterns; fix: recursively compile field patterns and emit constraints; deps: none; verification: zig build test
