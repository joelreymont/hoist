---
title: Emit sorted CFG ranges
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T23:07:18.224308+01:00\\\"\""
closed-at: "2026-02-17T23:10:23.742033+01:00"
close-reason: "discarded: unstable; rerun failed gate (large(100)+8.77%)"
---

Context: computeLivenessWithCFGInto appends ranges via hash-map iteration and leaves ranges_sorted_by_start false, so linear scan sorts every compile. Cause: unsorted range emission from vreg_ranges iterator. Fix: collect CFG live ranges, sort by start_inst once in liveness stage, then append in order and set ranges_sorted_by_start true. Verify: zig build test -j1 and same-tree A/B gate; keep only if >=5% retained gains and no regressions.
