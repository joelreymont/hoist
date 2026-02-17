---
title: Add dense vreg indexing
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.828135+01:00"
---

Context: src/regalloc/liveness.zig:500-620; cause: sparse hash-keyed vreg tracking increases overhead; fix: build compact vreg-id index table per function for dense bitset operations; deps: Speed up liveness analysis; verification: liveness tests pass and index mapping is stable across runs.
