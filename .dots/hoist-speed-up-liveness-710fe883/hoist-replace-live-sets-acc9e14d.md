---
title: Replace live sets with bitsets
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.833914+01:00\""
closed-at: "2026-02-17T14:19:40.114377+01:00"
close-reason: implemented DynamicBitSet-based live set propagation and benchmarked 5-run A/B, then discarded due regressions (fib +7.69%, parallel +6.93%, serial +1.65%; report /tmp/hoist-liveness-bitset-report.md) under >=5% keep rule
---

Context: src/regalloc/liveness.zig:366-497; cause: AutoHashMap set unions dominate fixed-point iteration cost; fix: use DynamicBitSetUnmanaged for live_in/live_out/new_live sets and bitwise union/diff; deps: Add dense vreg indexing; verification: identical live ranges on existing tests and lower liveness stage time.
