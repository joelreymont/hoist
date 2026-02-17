---
title: Tune alias threshold
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T22:32:48.586290+01:00\\\"\""
closed-at: "2026-02-17T22:35:16.792963+01:00"
close-reason: "discarded: failed gate (large(100)+21.05%, parallel batch+11.34%)"
---

Context: optimize stage remains expensive on small/medium compile benchmarks; alias analysis runs at complexity >=160. Cause: alias pass cost may outweigh compile-time benefit in this workload. Fix: raise default_alias_min_complexity and gate with existing complexity metric. Verify: zig build test -j1 and same-tree A/B gate, keep only if >=5% retained gains and zero regressions.
