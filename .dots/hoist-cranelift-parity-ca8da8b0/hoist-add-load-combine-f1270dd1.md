---
title: Add load combine
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.799826+02:00"
---

Files: docs/feature_gap_analysis.md:97-107
Root cause: no load/store combining pass.
Fix: add optimizer to fuse adjacent loads/stores into pair ops.
Why: memory throughput improvements.
Deps: none.
Verify: optimization tests.
