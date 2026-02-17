---
title: Binary-search active insert
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T21:58:46.114827+01:00\\\"\""
closed-at: "2026-02-17T22:01:21.825011+01:00"
close-reason: "discarded: no >=5% retained gain (best ~1.15% on key large metrics)"
---

Context: src/regalloc/linear_scan.zig insertActiveSorted currently linearly scans active ranges by end_inst on every allocation. Cause: O(n) search in hot regalloc loop with large active sets. Fix: switch to binary search insertion index while preserving stable ordering for equal end_inst. Why: reduce regalloc stage overhead on large functions. Verify: zig build test + bench A/B (>=5% retained, no regressions).
