---
title: Fix Branch Cleanup
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.402218+01:00"
---

Context: src/codegen/opts/simplifybranch.zig:75; cause: layout removal leaves DFG insts; fix: add DFG delete and use it; deps: hoist-plan-review-fixes-af4c6e65; verification: new simplifybranch tests
