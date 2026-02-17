---
title: Binary search spansCall
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T23:01:59.136659+01:00\\\"\""
closed-at: "2026-02-17T23:05:10.546378+01:00"
close-reason: "discarded: unstable; rerun failed gate (large(100)+8.77%)"
---

Context: liveness.spansCall is called per live range in linear scan and currently linearly scans all call positions. Cause: O(ranges*calls) overhead in regalloc stage. Fix: switch to binary search for first call > range.start and test strict interior semantics. Verify: zig build test -j1 and same-tree A/B gate; keep only if >=5% retained gains and no regressions.
