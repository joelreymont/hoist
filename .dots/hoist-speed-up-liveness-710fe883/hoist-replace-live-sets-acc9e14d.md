---
title: Replace live sets with bitsets
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.833914+01:00"
---

Context: src/regalloc/liveness.zig:366-497; cause: AutoHashMap set unions dominate fixed-point iteration cost; fix: use DynamicBitSetUnmanaged for live_in/live_out/new_live sets and bitwise union/diff; deps: Add dense vreg indexing; verification: identical live ranges on existing tests and lower liveness stage time.
