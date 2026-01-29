---
title: Fix IR Constants
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.344564+01:00"
---

Context: src/ir/optimize.zig:240; cause: optimizer emits value-less constants and invalid shifts; fix: store immediates and use proper shift immediate ops; deps: hoist-plan-review-fixes-af4c6e65; verification: new optimizer tests
