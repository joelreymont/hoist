---
title: Fix Egraph Constants
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.363822+01:00"
---

Context: src/ir/egraph.zig:29; cause: constants lack payload so predicates are wrong; fix: store const values and use in rules; deps: hoist-plan-review-fixes-af4c6e65; verification: egraph tests updated
