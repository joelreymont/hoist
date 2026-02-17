---
title: Use dense lookup in hot loops
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.857318+01:00\""
closed-at: "2026-02-17T14:26:17.831570+01:00"
close-reason: implemented active-interval dense preg side-table and benchmarked 5-run A/B, then discarded due regressions (fib +15.38%, large100 +6.63%, serial +6.13%; report /tmp/hoist-active-preg-report.md)
---

Context: src/regalloc/linear_scan.zig:300-430; cause: allocate/expire/spill repeatedly query maps; fix: refactor hot loops to direct array lookup and update paths; deps: Add array-backed alloc result; verification: large5000 regalloc stage time decreases and tests pass.
