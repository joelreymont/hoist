---
title: Add dense vreg indexing
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.828135+01:00\""
closed-at: "2026-02-17T14:32:49.858421+01:00"
close-reason: implemented dense vreg indexing for live-range reconstruction and benchmarked 5-run A/B, then discarded due regressions (fib +5.13%, large100 +9.69%, serial +5.44%; report /tmp/hoist-dense-vreg-report.md)
---

Context: src/regalloc/liveness.zig:500-620; cause: sparse hash-keyed vreg tracking increases overhead; fix: build compact vreg-id index table per function for dense bitset operations; deps: Speed up liveness analysis; verification: liveness tests pass and index mapping is stable across runs.
