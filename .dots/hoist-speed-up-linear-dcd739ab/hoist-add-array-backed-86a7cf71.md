---
title: Add array-backed alloc result
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.851126+01:00\""
closed-at: "2026-02-17T14:29:21.652546+01:00"
close-reason: implemented dense array-backed vreg side-tables in RegAllocResult and benchmarked 5-run A/B, then discarded due regressions/insufficient gains (fib +7.69%, large100 +1.53%, serial +1.58%; best win <5%; report /tmp/hoist-dense-result-report.md)
---

Context: src/regalloc/linear_scan.zig:45-90; cause: vreg_to_preg and vreg_to_spill hash lookups are hot; fix: introduce dense array-backed storage keyed by compact vreg index with fallback conversion only at boundaries; deps: Speed up liveness analysis; verification: regalloc unit tests pass with identical allocation behavior.
