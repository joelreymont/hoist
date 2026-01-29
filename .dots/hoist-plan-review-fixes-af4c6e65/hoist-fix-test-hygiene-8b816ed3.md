---
title: Fix Test Hygiene
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.574898+01:00"
---

Context: src/dsl/isle/ast.zig:182; cause: expectEqual on structs and missing snapshots; fix: switch to ohsnap and add zcheck invariants; deps: hoist-plan-review-fixes-af4c6e65; verification: zig build test
