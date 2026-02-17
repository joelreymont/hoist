---
title: Pre-size liveness maps
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T15:28:28.049897+01:00\\\"\""
closed-at: "2026-02-17T15:32:29.266891+01:00"
close-reason: "Completed: pre-sized ranges/vreg map in single-block liveness; A/B positive (>5%) on key large metrics; test+bench-gate passed."
---

Full context: computeLivenessInto updates vreg_to_range/ranges for every def/use and may rehash/reallocate repeatedly as vreg count grows with function size; cause is no capacity planning in hot single-block path; fix by pre-sizing ranges and vreg_to_range from instruction count; proof via same-tree A/B logs; keep only if >=5% positive gains.
