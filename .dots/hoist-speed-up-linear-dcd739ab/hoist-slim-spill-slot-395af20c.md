---
title: Slim spill slot bookkeeping
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.862785+01:00\""
closed-at: "2026-02-17T14:22:49.455142+01:00"
close-reason: attempted slimmer expire-path spill bookkeeping and benchmarked 5-run A/B, discarded due regressions (fib +10.26%, large100 +9.69%, large500 +5.88%; report /tmp/hoist-linear-expireopt-report.md)
---

Context: src/regalloc/linear_scan.zig:357-385; cause: active-list compaction and spill-slot map checks add overhead; fix: use compact free lists and direct state flags per interval; deps: Use dense lookup in hot loops; verification: no functional change in spill behavior tests and lower regalloc time.
