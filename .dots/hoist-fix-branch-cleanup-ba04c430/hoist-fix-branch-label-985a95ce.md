---
title: Fix Branch Label Resolution
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.416592+01:00"
---

Context: src/codegen/compile.zig:4511; cause: uses block index as label; fix: map blocks to labels after layout and patch branch targets; deps: hoist-fix-branch-cleanup-ba04c430; verification: e2e_branches tests
