---
title: Regalloc active head index
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T14:59:02.090041+01:00\\\"\""
closed-at: "2026-02-17T15:02:25.198346+01:00"
close-reason: "Discarded: A/B benchmark against old path regressed key metrics; see /tmp/hoist-head-ab.md."
---

Full context: src/regalloc/linear_scan.zig expireOldIntervals currently compacts active list with copyForwards each step, causing repeated O(n) front-copy churn; cause is eager compaction on every expire; fix by tracking active_start head index and compacting only when needed while preserving sorted order; proof via same-tree A/B logs and perf_gate compare; keep only if >=5% positive improvement on key metrics.
