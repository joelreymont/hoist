---
title: Add domtree test
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T21:20:37.778351+02:00"
---

File: tests/domtree.zig (new). Build CFG with diamond pattern (entry -> left/right -> exit). Compute dominators. Verify: entry dominates all, exit dominated by all, left/right dominated by entry only. ~15 min.
