---
title: Dense map for liveness uses
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T15:12:45.681509+01:00\\\"\""
closed-at: "2026-02-17T15:15:44.046675+01:00"
close-reason: "Discarded: A/B regressed key metrics (see /tmp/hoist-dense-ab.md); reverted."
---

Full context: incremental liveness now still does hash lookup per operand via vreg_to_range; cause is hash-table probe cost for every def/use; fix by using dense local vreg-index->range-index table during single-block scan and keeping hash map updates only on first-seen vregs; proof via same-tree A/B logs; keep only if >=5% positive gains.
